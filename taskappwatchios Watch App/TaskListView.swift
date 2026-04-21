import SwiftUI

// Mirrors Wear OS TaskListScreen: date navigation + task cards + Add button
struct TaskListView: View {
    let date: String
    @Binding var navPath: NavigationPath

    @ObservedObject private var store = TaskStore.shared
    @State private var displayDate: Date

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init(date: String, navPath: Binding<NavigationPath>) {
        self.date = date
        self._navPath = navPath
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        self._displayDate = State(initialValue: f.date(from: date) ?? Date())
    }

    private var dateKey: String { dateFmt.string(from: displayDate) }
    private var isToday: Bool { dateKey == DataClient.todayString() }

    private var tasks: [LocalTask] { store.getByDate(dateKey) }

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 8)

            // ── Date navigation ────────────────────────────────────
            HStack {
                Button { prevDay() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(isToday ? "Today" : displayDate.shortLabel)
                    .font(.michroma(12))
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button { nextDay() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isToday ? AppColors.textDim : AppColors.primary)
                }
                .disabled(isToday)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)

            Text("\(tasks.count) session\(tasks.count == 1 ? "" : "s")")
                .font(.michroma(8))
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 2)

            Spacer().frame(height: 8)

            // ── Task list ──────────────────────────────────────────
            if tasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textDim)
                    Text("No sessions")
                        .font(.michroma(10))
                        .foregroundColor(AppColors.textSecondary)
                    if isToday {
                        Button {
                            navPath.append(NavDest.addTask(startISO: isoNow()))
                        } label: {
                            Text("+ Log one")
                                .font(.michroma(10))
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule()
                                        .fill(AppColors.primary.opacity(0.15))
                                        .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.4), lineWidth: 1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(tasks) { task in
                            TaskCard(task: task)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }

            // ── Add button (today only) ────────────────────────────
            if isToday {
                Spacer().frame(height: 8)
                Button {
                    navPath.append(NavDest.addTask(startISO: isoNow()))
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        Text("Add").font(.michroma(11)).fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 28)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDk],
                                startPoint: .leading, endPoint: .trailing))
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 10, y: 3)
                    )
                }
                .buttonStyle(.plain)
                Spacer().frame(height: 8)
            }
        }
        .background(AppColors.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func prevDay() {
        displayDate = Calendar.current.date(byAdding: .day, value: -1, to: displayDate) ?? displayDate
    }

    private func nextDay() {
        guard !isToday else { return }
        displayDate = Calendar.current.date(byAdding: .day, value: 1, to: displayDate) ?? displayDate
    }

    private func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Task Card (mirrors Wear OS _TaskCard)
struct TaskCard: View {
    let task: LocalTask

    var body: some View {
        let color  = AppColors.forCategory(task.category)
        let icon   = categoryIcon(task.category)

        HStack(spacing: 8) {
            // Category icon circle
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title.isEmpty ? task.category : task.title)
                    .font(.michroma(11))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(task.timeRangeLabel)
                    .font(.michroma(8))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            // Duration badge
            Text(task.durationLabel)
                .font(.michroma(8))
                .fontWeight(.semibold)
                .foregroundColor(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(color.opacity(0.12)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.surface)
                HStack {
                    Rectangle().fill(color).frame(width: 3)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.surface2.opacity(0.5), lineWidth: 1)
            }
        )
    }
}

private extension Date {
    var shortLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: self)
    }
}
