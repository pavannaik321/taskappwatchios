import SwiftUI

// Mirrors Wear OS TaskSavedScreen: animated check circle → task info → countdown → auto-dismiss
struct TaskSavedView: View {
    let title:    String
    let startISO: String
    let endISO:   String
    let onDone:   () -> Void

    @State private var checkScale: CGFloat = 0
    @State private var fadeIn:     Double  = 0
    @State private var countdown:  Int     = 4

    private let isoFmt = ISO8601DateFormatter()
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    private var start:    Date { isoFmt.date(from: startISO) ?? Date() }
    private var end:      Date { isoFmt.date(from: endISO)   ?? Date() }
    private var durLabel: String { durationLabel(from: start, to: end) }
    private var timeRange: String { "\(timeFmt.string(from: start)) – \(timeFmt.string(from: end))" }

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Check circle (elastic spring in) ───────────────
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .overlay(Circle().strokeBorder(AppColors.accent, lineWidth: 2))
                        .frame(width: 52, height: 52)
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(AppColors.accent)
                }
                .scaleEffect(checkScale)

                Spacer().frame(height: 10)

                // ── "Logged!" ──────────────────────────────────────
                Text("Logged!")
                    .font(.michroma(15))
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .kerning(-0.4)

                Spacer().frame(height: 3)

                Text(title)
                    .font(.michroma(10))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)

                Spacer().frame(height: 10)

                // ── Time card ──────────────────────────────────────
                HStack(spacing: 0) {
                    Rectangle().fill(AppColors.accent).frame(width: 2.5)
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                        Text(timeRange)
                            .font(.michroma(9))
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text(durLabel)
                            .font(.michroma(8))
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppColors.accent.opacity(0.15)))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(RoundedRectangle(cornerRadius: 10).fill(AppColors.surface))
                .padding(.horizontal, 16)

                Spacer().frame(height: 14)

                // ── Countdown progress bar ─────────────────────────
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.surface2)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(AppColors.primary)
                            .frame(width: geo.size.width * CGFloat(countdown) / 4.0, height: 3)
                            .animation(.linear(duration: 1), value: countdown)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 16)

                Spacer().frame(height: 5)

                Text("Back in \(countdown)…")
                    .font(.michroma(8))
                    .foregroundColor(AppColors.textDim)

                Spacer().frame(height: 8)

                // ── Done tap ───────────────────────────────────────
                Button(action: onDone) {
                    Text("Done")
                        .font(.michroma(10))
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .opacity(fadeIn)
        }
        .onAppear {
            // Elastic spring for check circle
            withAnimation(.interpolatingSpring(stiffness: 140, damping: 10).delay(0.05)) {
                checkScale = 1.0
            }
            withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                fadeIn = 1.0
            }
            // Countdown timer
            startCountdown()
        }
        .navigationBarBackButtonHidden(true)
    }

    private func startCountdown() {
        Swift.Task {
            for _ in 0..<4 {
                try? await Swift.Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { countdown -= 1 }
                if countdown <= 0 { break }
            }
            await MainActor.run { onDone() }
        }
    }
}
