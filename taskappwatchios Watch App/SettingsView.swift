import SwiftUI
import UserNotifications

// Mirrors Wear OS SettingsScreen: schedule (read-only) → notifications → account → re-pair → sign out
struct SettingsView: View {
    let onSignOut: () -> Void

    @State private var interval:   Int  = 60
    @State private var workStart:  Int  = 8
    @State private var workEnd:    Int  = 20
    @State private var notifsOn:   Bool = true
    @State private var user:       UserModel?
    @State private var testFired:  Bool = false
    @State private var testErr:    String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 20)

                // Header
                HStack(spacing: 5) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.textSecondary)
                    Text("Settings")
                        .font(.michroma(14))
                        .fontWeight(.heavy)
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.bottom, 16)

                // ── Schedule (read-only from phone) ────────────────
                SettingsLabel("SCHEDULE FROM PHONE")
                Spacer().frame(height: 6)

                VStack(spacing: 6) {
                    SettingsInfoRow(icon: "timer", label: "Interval: \(fmtInterval(interval))")
                    SettingsInfoRow(icon: "sun.max", label: "Start: \(fmtHour(workStart))")
                    SettingsInfoRow(icon: "moon",    label: "End: \(fmtHour(workEnd))")
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
                )

                Spacer().frame(height: 16)

                // ── Notifications ──────────────────────────────────
                SettingsLabel("NOTIFICATIONS")
                Spacer().frame(height: 6)

                // Enable / disable toggle
                HStack(spacing: 8) {
                    Image(systemName: notifsOn ? "bell.badge.fill" : "bell.slash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(notifsOn ? AppColors.textPrimary : AppColors.textDim)
                    Text("Watch Notifications")
                        .font(.michroma(10))
                        .foregroundColor(notifsOn ? AppColors.textPrimary : AppColors.textDim)
                    Spacer()
                    Toggle("", isOn: $notifsOn)
                        .labelsHidden()
                        .scaleEffect(0.75)
                        .tint(AppColors.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
                )

                Spacer().frame(height: 6)

                // Test notification button
                Button { fireTest() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: testErr != nil ? "exclamationmark.circle" : testFired ? "checkmark" : "bell.and.waves.left.and.right")
                            .font(.system(size: 13))
                            .foregroundColor(testErr != nil ? AppColors.error : testFired ? AppColors.textSecondary : (notifsOn ? AppColors.textPrimary : AppColors.textDim))
                        Text(testErr != nil ? "Error" : testFired ? "Sent!" : "Test Check-in Notification")
                            .font(.michroma(10))
                            .foregroundColor(testErr != nil ? AppColors.error : testFired ? AppColors.textSecondary : (notifsOn ? AppColors.textPrimary : AppColors.textDim))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(testErr != nil ? AppColors.error.opacity(0.08) : AppColors.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(
                                testErr != nil ? AppColors.error.opacity(0.4) : testFired ? AppColors.textSecondary : AppColors.surface2,
                                lineWidth: 1))
                    )
                }
                .disabled(!notifsOn || testFired)
                .buttonStyle(.plain)
                .opacity(!notifsOn ? 0.35 : 1)

                Spacer().frame(height: 16)

                // ── Account ────────────────────────────────────────
                SettingsLabel("ACCOUNT")
                Spacer().frame(height: 6)

                VStack(spacing: 6) {
                    if let u = user {
                        SettingsInfoRow(icon: "person.circle", label: u.displayName)
                        if !u.email.isEmpty {
                            SettingsInfoRow(icon: "at", label: u.email)
                        }
                        SettingsInfoRow(
                            icon: "crown.fill",
                            label: u.isPlanExpired ? "\(u.plan.uppercased()) — EXPIRED" : u.plan.uppercased(),
                            isExpired: u.isPlanExpired
                        )
                    } else {
                        SettingsInfoRow(icon: "person.circle", label: "Guest")
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
                )

                Spacer().frame(height: 16)

                // ── Phone Pairing ──────────────────────────────────
                SettingsLabel("PHONE PAIRING")
                Spacer().frame(height: 6)

                Button(action: onSignOut) {
                    HStack(spacing: 6) {
                        Image(systemName: "link").font(.system(size: 13)).foregroundColor(AppColors.textSecondary)
                        Text("Re-Pair Watch").font(.michroma(11)).fontWeight(.semibold).foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(AppColors.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 16)

                // ── Sign Out ───────────────────────────────────────
                if user != nil {
                    Button {
                        DataClient.shared.logout()
                        onSignOut()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 13)).foregroundColor(AppColors.error)
                            Text("Sign Out").font(.michroma(11)).fontWeight(.semibold).foregroundColor(AppColors.error)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppColors.error.opacity(0.08))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.error.opacity(0.3), lineWidth: 1))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 14)
        }
        .background(AppColors.bg)
        .onAppear {
            let d = UserDefaults.standard
            interval   = d.integer(forKey: "watch_interval").nonZeroOrDefault(60)
            workStart  = d.integer(forKey: "watch_work_start").nonZeroOrDefault(8)
            workEnd    = d.integer(forKey: "watch_work_end").nonZeroOrDefault(20)
            user = DataClient.shared.currentUser()
        }
    }

    private func fireTest() {
        testFired = true; testErr = nil

        let content = UNMutableNotificationContent()
        content.title = "Time to log!"
        content.body = "What have you been working on? Tap to record."
        content.sound = .default

        // Fires 3 seconds after tapping the button so user can see it arrive
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-checkin-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error {
                    testErr = error.localizedDescription
                    testFired = false
                }
                // Reset "Sent!" badge after 4s
                Swift.Task {
                    try? await Swift.Task.sleep(nanoseconds: 4_000_000_000)
                    await MainActor.run { testFired = false }
                }
            }
        }
    }

    private func fmtHour(_ h: Int) -> String {
        if h == 0 || h == 24 { return "12:00 AM" }
        if h < 12  { return "\(h):00 AM" }
        if h == 12 { return "12:00 PM" }
        return "\(h - 12):00 PM"
    }

    private func fmtInterval(_ m: Int) -> String {
        if m < 60 { return "\(m)m" }
        if m % 60 == 0 { return "\(m / 60)h" }
        return "\(m / 60)h \(m % 60)m"
    }
}

// MARK: - Shared Settings sub-widgets

struct SettingsLabel: View {
    let text: String
    init(_ t: String) { text = t }

    var body: some View {
        Text(text)
            .font(.michroma(7.5))
            .fontWeight(.bold)
            .foregroundColor(AppColors.textDim)
            .kerning(1.0)
    }
}

struct SettingsInfoRow: View {
    let icon: String
    let label: String
    var isExpired: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isExpired ? AppColors.error : AppColors.textSecondary)
            Text(label)
                .font(.michroma(10))
                .fontWeight(.medium)
                .foregroundColor(isExpired ? AppColors.error : AppColors.textPrimary)
                .lineLimit(1)
        }
    }
}

private extension Int {
    func nonZeroOrDefault(_ d: Int) -> Int { self == 0 ? d : self }
}
