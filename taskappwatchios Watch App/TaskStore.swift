import Foundation
import Combine

/// Offline-first local task storage backed by UserDefaults JSON.
/// Mirrors Hive storage from the Wear OS app.
class TaskStore: ObservableObject {
    static let shared = TaskStore()

    @Published private(set) var tasks: [LocalTask] = []

    private let key = "local_tasks_v1"

    init() {
        load()
        deduplicateLocalStore()
    }

    // MARK: - Startup dedup
    // Cleans up duplicate tasks that may exist in UserDefaults from before
    // the clientTaskId de-dup fix. Groups by startTime+date, keeps one per slot.
    private func deduplicateLocalStore() {
        // Group tasks by date + rounded startTime (same minute = same slot)
        var seen: [String: Int] = [:]   // key → index of task to keep
        var indicesToRemove: [Int] = []

        for (i, task) in tasks.enumerated() {
            let key = "\(task.date)|\(Int(task.startTime.timeIntervalSince1970 / 60))"
            if let existing = seen[key] {
                // Prefer synced tasks; among equals prefer MongoDB-style id (24 hex chars)
                let currentIsMongoId = tasks[existing].id.count == 24
                let newIsMongoId     = task.id.count == 24
                if (!currentIsMongoId && newIsMongoId) || (!tasks[existing].isSynced && task.isSynced) {
                    indicesToRemove.append(existing)
                    seen[key] = i
                } else {
                    indicesToRemove.append(i)
                }
            } else {
                seen[key] = i
            }
        }

        guard !indicesToRemove.isEmpty else { return }
        for idx in indicesToRemove.sorted(by: >) {
            tasks.remove(at: idx)
        }
        persist()
    }

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
        tasks.filter { $0.date == date }.sorted { $0.startTime > $1.startTime }
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
    /// Matches by backend _id first, then by clientTaskId (the UUID we sent on create).
    /// This prevents duplicates when a locally-created task is fetched back with a new MongoDB _id.
    func mergeRemote(_ items: [TaskItem], userId: String) {
        let isoFmt = ISO8601DateFormatter()
        isoFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFmtBasic = ISO8601DateFormatter()

        func parseDate(_ str: String) -> Date? {
            isoFmt.date(from: str) ?? isoFmtBasic.date(from: str)
        }

        for item in items {
            guard let start = parseDate(item.startTime),
                  let end   = parseDate(item.endTime) else { continue }

            // Try to find existing local task: first by backend _id, then by clientTaskId
            let byId         = tasks.firstIndex(where: { $0.id == item.id })
            let byClientId   = item.clientTaskId.flatMap { cid in
                tasks.firstIndex(where: { $0.id == cid })
            }
            let existingIdx  = byId ?? byClientId

            if let idIdx = byId, let clientIdx = byClientId, idIdx != clientIdx {
                // Both the mongo-id version AND the old UUID-id version exist in local store
                // (stale duplicate from before clientTaskId fix) — remove both, keep one clean copy
                let higher = max(idIdx, clientIdx)
                let lower  = min(idIdx, clientIdx)
                tasks.remove(at: higher)
                tasks.remove(at: lower)
                tasks.append(LocalTask(
                    id:           item.id,
                    title:        item.title,
                    category:     item.category ?? "General",
                    startTime:    start,
                    endTime:      end,
                    date:         item.date,
                    isQuickEntry: tasks[safe: lower]?.isQuickEntry ?? false,
                    isSynced:     true,
                    userId:       userId
                ))
            } else if let idx = existingIdx {
                // Single match — promote local UUID to backend _id, mark synced
                tasks[idx].id = item.id
                if tasks[idx].isSynced {
                    tasks[idx].title     = item.title
                    tasks[idx].category  = item.category ?? "General"
                    tasks[idx].startTime = start
                    tasks[idx].endTime   = end
                }
                tasks[idx].isSynced = true
            } else {
                // New task from backend not yet in local store
                tasks.append(LocalTask(
                    id:           item.id,
                    title:        item.title,
                    category:     item.category ?? "General",
                    startTime:    start,
                    endTime:      end,
                    date:         item.date,
                    isQuickEntry: false,
                    isSynced:     true,
                    userId:       userId
                ))
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
                    id:              task.id,   // backend reads as clientTaskId for de-dup
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
