import Foundation
import Combine

/// Offline-first local task storage backed by UserDefaults JSON.
/// Mirrors Hive storage from the Wear OS app.
class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var tasks: [LocalTask] = []

    private let key = "local_tasks_v1"

    init() { load() }

    // MARK: - CRUD

    func save(_ task: LocalTask) {
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx] = task
        } else {
            tasks.append(task)
        }
        persist()
    }

    // MARK: - Queries

    func getByDate(_ date: String) -> [LocalTask] {
        tasks.filter { $0.date == date }.sorted { $0.startTime < $1.startTime }
    }

    /// Returns slot start times for today that have no matching logged task.
    func missedSlots(for date: String) -> [Date] {
        let defaults = UserDefaults.standard
        let interval  = defaults.integer(forKey: "watch_interval").nonZeroOr(60)
        let workStart = defaults.integer(forKey: "watch_work_start").nonZeroOr(8)
        let workEnd   = defaults.integer(forKey: "watch_work_end").nonZeroOr(20)

        let cal  = Calendar.current
        let now  = Date()
        let dayTasks = getByDate(date)

        guard let base = cal.date(from: cal.dateComponents([.year,.month,.day], from: now)),
              let startOfWork = cal.date(bySettingHour: workStart, minute: 0, second: 0, of: base),
              let endOfWork   = cal.date(bySettingHour: workEnd,   minute: 0, second: 0, of: base)
        else { return [] }

        var slots: [Date] = []
        var slotTime = startOfWork
        while slotTime < endOfWork && slotTime < now {
            slots.append(slotTime)
            slotTime = slotTime.addingTimeInterval(Double(interval) * 60)
        }

        return slots.filter { slot in
            let slotEnd = slot.addingTimeInterval(Double(interval) * 60)
            return !dayTasks.contains { t in
                t.startTime < slotEnd && t.endTime > slot
            }
        }
    }

    func intervalMinutes() -> Int {
        UserDefaults.standard.integer(forKey: "watch_interval").nonZeroOr(60)
    }

    // MARK: - Sync

    /// Merges tasks fetched from backend into local store.
    /// Remote tasks are marked isSynced=true. Locally-created unsynced tasks are never overwritten.
    func mergeRemote(_ items: [TaskItem], userId: String) {
        // Backend returns fractional-second ISO8601 (e.g. "2026-04-21T10:30:00.000+00:00").
        // The default ISO8601DateFormatter doesn't handle .000 — must enable fractional seconds.
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFmtBasic = ISO8601DateFormatter() // fallback for dates without ms

        func parseDate(_ str: String) -> Date? {
            isoFmt.date(from: str) ?? isoFmtBasic.date(from: str)
        }

        for item in items {
            guard let start = parseDate(item.startTime),
                  let end   = parseDate(item.endTime) else { continue }
            if let idx = tasks.firstIndex(where: { $0.id == item.id }) {
                // Update only if already synced (don't clobber pending local edits)
                if tasks[idx].isSynced {
                    tasks[idx].title    = item.title
                    tasks[idx].category = item.category ?? "General"
                    tasks[idx].startTime = start
                    tasks[idx].endTime   = end
                }
            } else {
                let local = LocalTask(
                    id:             item.id,
                    title:          item.title,
                    category:       item.category ?? "General",
                    startTime:      start,
                    endTime:        end,
                    date:           item.date,
                    isQuickEntry:   false,
                    isSynced:       true,
                    userId:         userId
                )
                tasks.append(local)
            }
        }
        persist()
    }

    func syncToServer() {
        Swift.Task {
            let unsynced = tasks.filter { !$0.isSynced }
            guard !unsynced.isEmpty else { return }

            let isoFmt  = ISO8601DateFormatter()
            let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"

            for task in unsynced {
                let body = CreateTaskBody(
                    title:           task.title,
                    category:        task.category,
                    startTime:       isoFmt.string(from: task.startTime),
                    endTime:         isoFmt.string(from: task.endTime),
                    date:            task.date,
                    isQuickEntry:    task.isQuickEntry,
                    intervalMinutes: task.durationMinutes
                )
                do {
                    try await DataClient.shared.createTask(body)
                    await MainActor.run {
                        if let idx = self.tasks.firstIndex(where: { $0.id == task.id }) {
                            self.tasks[idx].isSynced = true
                        }
                    }
                } catch { /* retry next time */ }
            }
            await MainActor.run { self.persist() }
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data   = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([LocalTask].self, from: data)
        else { return }
        tasks = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}
