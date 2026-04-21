import SwiftUI
import Combine

// MARK: - Navigation destinations (mirrors Go Router routes in Wear OS)
enum NavDest: Hashable {
    case settings
    case taskList
    case addTask(startISO: String)
    case quickTask(startISO: String, intervalMinutes: Int)
    case speechRecord(startISO: String, intervalMinutes: Int)
    case taskSaved(title: String, startISO: String, endISO: String)
    case missedText(startISO: String, intervalMinutes: Int)
}

// MARK: - Home Shell (3-page PageView: TODAY | MISSED | PROFILE)
// Mirrors Wear OS HomeScreen with PageView + page label + indicator dots
struct HomeView: View {
    let onLogout: () -> Void

    @StateObject private var store = TaskStore.shared
    @State private var page      = 0
    @State private var navPath   = NavigationPath()

    private let labels = ["TODAY", "MISSED", "PROFILE"]
    private let today  = DataClient.todayString()

    var body: some View {
        NavigationStack(path: $navPath) {
            GeometryReader { geo in
                ZStack {
                    AppColors.bg.ignoresSafeArea()

                    // ── 3-page swiping content ─────────────────────────
                    TabView(selection: $page) {
                        TodayPage(store: store, today: today, navPath: $navPath)
                            .tag(0)
                        MissedPage(store: store, today: today, navPath: $navPath)
                            .tag(1)
                        ProfilePage(onLogout: onLogout, onSettings: {
                            navPath.append(NavDest.settings)
                        })
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // ── Page label (top) ───────────────────────────────
                    VStack {
                        Text(labels[page])
                            .font(.michroma(8))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textDim)
                            .kerning(1.4)
                            .padding(.top, geo.safeAreaInsets.top > 0 ? 2 : 4)
                            .id(page) // forces AnimatedSwitcher-style rebuild
                            .animation(.none, value: page)

                        Spacer()

                        // ── Page indicator dots (bottom) ───────────────
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule()
                                    .fill(i == page ? AppColors.primary : AppColors.ring)
                                    .frame(width: i == page ? 14 : 5, height: 5)
                                    .animation(.easeInOut(duration: 0.22), value: page)
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .allowsHitTesting(false)
                }
            }
            // ── Navigation destinations (mirrors Go Router routes) ──
            .navigationDestination(for: NavDest.self) { dest in
                switch dest {
                case .settings:
                    SettingsView(onSignOut: {
                        navPath = NavigationPath()
                        onLogout()
                    })
                case .taskList:
                    TaskListView(date: today, navPath: $navPath)
                case .addTask(let startISO):
                    AddTaskView(startISO: startISO, store: store, onSaved: { title, s, e in
                        navPath.append(NavDest.taskSaved(title: title, startISO: s, endISO: e))
                    })
                case .quickTask(let startISO, let interval):
                    QuickTaskView(startISO: startISO, intervalMinutes: interval, store: store, onSaved: { title, s, e in
                        navPath.append(NavDest.taskSaved(title: title, startISO: s, endISO: e))
                    })
                case .taskSaved(let title, let s, let e):
                    TaskSavedView(title: title, startISO: s, endISO: e, onDone: {
                        navPath = NavigationPath()
                    })
                case .speechRecord(let startISO, let interval):
                    SpeechRecordView(startISO: startISO, intervalMinutes: interval, store: store, onSaved: { title, s, e in
                        navPath.append(NavDest.taskSaved(title: title, startISO: s, endISO: e))
                    })
                case .missedText(let startISO, let interval):
                    MissedTextView(startISO: startISO, intervalMinutes: interval, store: store, onSaved: {
                        navPath = NavigationPath()
                    })
                }
            }
        }
    }
}

// MARK: - Page 0 · Today
// Mirrors Wear OS _TodayPage
struct TodayPage: View {
    @ObservedObject var store: TaskStore
    let today: String
    @Binding var navPath: NavigationPath

    @State private var summary:    DaySummary?
    @State private var isLoading:  Bool = false
    @State private var dotPhase:   Double = 0

    private let dotTimer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        let tasks = store.getByDate(today)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: topPad)

                if isLoading && tasks.isEmpty {
                    loadingView
                } else if tasks.isEmpty {
                    emptyState
                } else {
                    // Progress bar
                    if let sum = summary, sum.totalTasks > 0 || tasks.count > 0 {
                        let expected = max(sum.totalTasks, tasks.count)
                        let fraction = min(1.0, Double(tasks.count) / Double(max(1, expected)))
                        HStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.surface2)
                                        .frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AppColors.primary)
                                        .frame(width: geo.size.width * fraction, height: 5)
                                }
                            }
                            .frame(height: 5)
                            Text("\(tasks.count)")
                                .font(.michroma(8))
                                .foregroundColor(AppColors.textDim)
                        }
                        .padding(.bottom, 10)
                    }

                    sectionLabel("LOGGED · \(tasks.count)")
                    Spacer().frame(height: 5)
                    ForEach(tasks) { task in
                        TaskTile(task: task)
                            .padding(.bottom, 5)
                    }
                }

                Spacer().frame(height: bottomPad)
            }
            .padding(.horizontal, hPad)
        }
        .background(AppColors.bg)
        .refreshable { await reload() }
        .task { await reload() }
        .onReceive(dotTimer) { _ in
            dotPhase = (dotPhase + 1/33.0).truncatingRemainder(dividingBy: 1)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 40)
            PulsingDots(phase: dotPhase)
            Text("Getting your data...")
                .font(.michroma(8))
                .foregroundColor(AppColors.textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer().frame(height: 20)
            Image(systemName: "note.text")
                .font(.system(size: 26))
                .foregroundColor(AppColors.textDim)
            Text("No logs yet")
                .font(.michroma(11))
                .foregroundColor(AppColors.textSecondary)
            Text("Swipe left to fill\nmissed slots")
                .font(.michroma(8))
                .foregroundColor(AppColors.textDim)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
    }

    private func reload() async {
        isLoading = true
        async let remoteSummary = DataClient.shared.fetchSummary(for: today)
        async let remoteTasks   = DataClient.shared.fetchTasks(for: today)

        summary = try? await remoteSummary

        if let fetched = try? await remoteTasks {
            let userId = DataClient.shared.currentUser()?.id ?? ""
            await MainActor.run { store.mergeRemote(fetched, userId: userId) }
        }

        isLoading = false
    }
}

// MARK: - Page 1 · Missed
// Mirrors Wear OS _MissedPage
struct MissedPage: View {
    @ObservedObject var store: TaskStore
    let today: String
    @Binding var navPath: NavigationPath

    var body: some View {
        let missed   = store.missedSlots(for: today)
        let interval = store.intervalMinutes()

        if missed.isEmpty {
            missedEmpty
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: topPad)

                    // Count pill
                    HStack {
                        Text("\(missed.count) unfilled")
                            .font(.michroma(7.5))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppColors.error.opacity(0.15))
                                    .overlay(Capsule().strokeBorder(AppColors.error.opacity(0.4), lineWidth: 1))
                            )
                        Spacer()
                    }
                    .padding(.bottom, 8)

                    ForEach(missed, id: \.self) { slot in
                        MissedSlotCard(
                            slot: slot,
                            intervalMinutes: interval,
                            onRecord: { startISO in
                                navPath.append(NavDest.speechRecord(startISO: startISO, intervalMinutes: interval))
                            },
                            onText: { startISO in
                                navPath.append(NavDest.missedText(startISO: startISO, intervalMinutes: interval))
                            }
                        )
                        .padding(.bottom, 7)
                    }

                    Spacer().frame(height: bottomPad)
                }
                .padding(.horizontal, hPad)
            }
            .background(AppColors.bg)
        }
    }

    private var missedEmpty: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(AppColors.surface2).frame(width: 44, height: 44)
                Image(systemName: "checkmark").foregroundColor(AppColors.textPrimary).font(.system(size: 24))
            }
            Text("All caught up!")
                .font(.michroma(12))
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            Text("No missed slots")
                .font(.michroma(8.5))
                .foregroundColor(AppColors.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bg)
    }
}

// MARK: - Page 2 · Profile
// Mirrors Wear OS _ProfilePage
struct ProfilePage: View {
    let onLogout: () -> Void
    let onSettings: () -> Void

    @State private var user: UserModel? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: topPad)

                // Avatar circle
                ZStack {
                    Circle()
                        .fill(AppColors.surface2)
                        .overlay(Circle().strokeBorder(AppColors.surface2, lineWidth: 2))
                        .frame(width: 46, height: 46)
                    Text(user?.initials ?? "U")
                        .font(.michroma(20))
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer().frame(height: 8)

                Text(user?.displayName ?? "User")
                    .font(.michroma(12))
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)

                Spacer().frame(height: 4)

                // Plan badge
                let expired = user?.isPlanExpired ?? false
                let planText = expired ? "Expired" : (user?.planLabel ?? "Free")
                Text(planText)
                    .font(.michroma(7.5))
                    .fontWeight(.bold)
                    .foregroundColor(expired ? AppColors.error : AppColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(expired ? AppColors.error.opacity(0.12) : AppColors.surface2)
                            .overlay(Capsule().strokeBorder(
                                expired ? AppColors.error.opacity(0.5) : AppColors.textDim, lineWidth: 1))
                    )

                if expired {
                    Text("Plan expired — re-pair\nto restore access")
                        .font(.michroma(7.5))
                        .foregroundColor(AppColors.error.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.top, 6)
                }

                Spacer().frame(height: 20)

                ActionRow(icon: "gearshape.fill", label: "Settings", onTap: onSettings)
                Spacer().frame(height: 8)
                ActionRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign Out",
                          isDestructive: true, onTap: onLogout)

                Spacer().frame(height: bottomPad)
            }
            .padding(.horizontal, hPad)
        }
        .background(AppColors.bg)
        .onAppear {
            Swift.Task { @MainActor in user = DataClient.shared.currentUser() }
        }
    }
}

// MARK: - Shared layout constants
private let hPad:     CGFloat = 16
private let topPad:   CGFloat = 26
private let bottomPad: CGFloat = 22

// MARK: - Shared widgets

struct TaskTile: View {
    let task: LocalTask

    var body: some View {
        let color = AppColors.forCategory(task.category)
        let fmt   = DateFormatter(); let _ = (fmt.dateFormat = "hh:mm a")

        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.85))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.michroma(10))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(fmt.string(from: task.startTime))
                    .font(.michroma(7.5))
                    .foregroundColor(AppColors.textDim)
            }
            Spacer()
            if !task.isSynced {
                Image(systemName: "icloud.slash")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.textDim)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
        )
    }
}

struct MissedSlotCard: View {
    let slot: Date
    let intervalMinutes: Int
    let onRecord: (String) -> Void
    let onText: (String) -> Void

    var body: some View {
        let slotEnd    = slot.addingTimeInterval(Double(intervalMinutes) * 60)
        let fmt        = DateFormatter(); let _ = (fmt.dateFormat = "h:mm")
        let fmtAMPM    = DateFormatter(); let _ = (fmtAMPM.dateFormat = "h:mm a")
        let startLabel = fmt.string(from: slot)
        let endLabel   = fmtAMPM.string(from: slotEnd)
        let isoFmt     = ISO8601DateFormatter()
        let startISO   = isoFmt.string(from: slot)

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.error.opacity(0.7))
                    .frame(width: 6, height: 6)
                Text("\(startLabel) – \(endLabel)")
                    .font(.michroma(9.5))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
            }

            HStack(spacing: 5) {
                // Record (outline style) → Quick Log
                Button { onRecord(startISO) } label: {
                    Label("Record", systemImage: "mic.fill")
                        .font(.michroma(8))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.surface2)
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(AppColors.surface2, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                // Text (filled style)
                Button { onText(startISO) } label: {
                    Label("Text", systemImage: "pencil")
                        .font(.michroma(8))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(EdgeInsets(top: 9, leading: 10, bottom: 9, trailing: 8))
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(AppColors.surface)
                HStack {
                    Rectangle()
                        .fill(AppColors.error.opacity(0.6))
                        .frame(width: 2.5)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.surface2, lineWidth: 1)
            }
        )
    }
}

struct ActionRow: View {
    let icon: String
    let label: String
    var isDestructive: Bool = false
    let onTap: () -> Void

    var body: some View {
        let color: Color = isDestructive ? AppColors.error : AppColors.textSecondary

        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(label)
                    .font(.michroma(11))
                    .fontWeight(.semibold)
                    .foregroundColor(isDestructive ? AppColors.error : AppColors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textDim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDestructive ? AppColors.error.opacity(0.08) : AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isDestructive ? AppColors.error.opacity(0.3) : AppColors.surface2, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

func sectionLabel(_ text: String) -> some View {
    Text(text)
        .font(.michroma(7.5))
        .fontWeight(.bold)
        .foregroundColor(AppColors.textDim)
        .kerning(1.0)
}
