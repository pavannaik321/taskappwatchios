import SwiftUI
import Combine

// Mirrors the Wear OS SplashScreen: concentric rings → TOCKLOG title → pulsing dots → status → navigate
struct SplashView: View {
    let onComplete: (Bool) -> Void

    @State private var logoScale:      CGFloat = 0.5
    @State private var logoOpacity:    Double  = 0
    @State private var textSlide:      CGFloat = 20
    @State private var textOpacity:    Double  = 0
    @State private var taglineOpacity: Double  = 0
    @State private var dotPhase:       Double  = 0
    @State private var status:         String  = "Initialising..."

    private let dotTimer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Logo with concentric rings ─────────────────────────
                logoView
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)

                Spacer().frame(height: 16)

                // ── TOCKLOG + tagline ──────────────────────────────────
                VStack(spacing: 5) {
                    Text("TOCKLOG")
                        .font(.michroma(15))
                        .foregroundColor(AppColors.textPrimary)
                        .kerning(3.5)

                    Text("Track your time")
                        .font(.michroma(7.5))
                        .foregroundColor(AppColors.textDim)
                        .kerning(0.8)
                        .opacity(taglineOpacity)
                }
                .offset(y: textSlide)
                .opacity(textOpacity)

                Spacer().frame(height: 24)

                // ── Pulsing dots ───────────────────────────────────────
                PulsingDots(phase: dotPhase)
                    .opacity(textOpacity)

                Spacer().frame(height: 10)

                // ── Live status text ───────────────────────────────────
                Text(status)
                    .font(.michroma(7))
                    .foregroundColor(AppColors.textDim)
                    .kerning(0.5)
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.3), value: status)

                Spacer()
            }
        }
        .onReceive(dotTimer) { _ in
            dotPhase = (dotPhase + 1/33.0).truncatingRemainder(dividingBy: 1)
        }
        .onAppear {
            animate()
            Swift.Task { await runInit() }
        }
    }

    // MARK: - Logo

    private var logoView: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                .frame(width: 62, height: 62)
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 52, height: 52)
            ZStack {
                Circle()
                    .fill(AppColors.surface)
                    .overlay(Circle().strokeBorder(AppColors.surface2, lineWidth: 1.5))
                    .shadow(color: Color.white.opacity(0.05), radius: 8)
                Image(systemName: "clock.fill")
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(width: 44, height: 44)
        }
    }

    // MARK: - Animation sequence

    private func animate() {
        withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
            logoScale   = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.65)) {
            textSlide   = 0
            textOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
            taglineOpacity = 1.0
        }
    }

    // MARK: - Init logic (mirrors Wear OS SplashScreen._init)

    @MainActor private func runInit() async {
        let loggedIn = DataClient.shared.isLoggedIn  // read before any suspension

        await sleep(ms: 600)
        status = "Authenticating..."

        if loggedIn {
            await sleep(ms: 300)
            status = "Getting your data..."
            await sleep(ms: 600)
            status = "Almost there..."
            await sleep(ms: 400)
        } else {
            await sleep(ms: 300)
            status = "Please pair your watch..."
            await sleep(ms: 500)
        }

        // Flush any notification deep-link stored while app was dead
        NotificationManager.flushPendingNavIfNeeded()
        onComplete(loggedIn)
    }

    private func sleep(ms: UInt64) async { try? await Swift.Task.sleep(nanoseconds: ms * 1_000_000) }
}

// MARK: - Pulsing Dots (shared by Splash + PinLogin)
struct PulsingDots: View {
    let phase: Double

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                let p = (phase - Double(i) / 3.0).truncatingRemainder(dividingBy: 1)
                let normalised = p < 0 ? p + 1 : p
                let opacity = clampValue(0.5 - 0.5 * cos(normalised * 2 * .pi), lo: 0.2, hi: 1.0)
                Circle()
                    .fill(AppColors.textSecondary)
                    .frame(width: 4.5, height: 4.5)
                    .opacity(opacity)
            }
        }
    }
}
