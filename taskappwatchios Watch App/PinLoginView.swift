import SwiftUI
import Combine

// Mirrors Wear OS WatchPairScreen: logo → PIN slots → custom numpad → authenticating view
struct PinLoginView: View {
    let onLogin: () -> Void

    @State private var digits:    [String] = []
    @State private var isLoading: Bool     = false
    @State private var error:     String?  = nil
    @State private var dotPhase:  Double   = 0

    private let dotTimer = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            if isLoading {
                authenticatingView
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                pinEntryView
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isLoading)
        .onReceive(dotTimer) { _ in
            if isLoading {
                dotPhase = (dotPhase + 1/33.0).truncatingRemainder(dividingBy: 1)
            }
        }
    }

    // MARK: - Authenticating view (mirrors _AuthenticatingView)
    private var authenticatingView: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 62, height: 62)
                Circle()
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 52, height: 52)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            }

            Spacer().frame(height: 16)

            Text("TOCKLOG")
                .font(.michroma(12))
                .foregroundColor(AppColors.textPrimary)
                .kerning(3)

            Spacer().frame(height: 24)

            PulsingDots(phase: dotPhase)

            Spacer().frame(height: 10)

            Text("Authenticating...")
                .font(.michroma(7.5))
                .foregroundColor(AppColors.textDim)
                .kerning(0.5)
        }
    }

    // MARK: - PIN entry view (mirrors _PinEntryView)
    private var pinEntryView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 12)

                // App icon
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer().frame(height: 6)

                Text("TOCKLOG")
                    .font(.michroma(10))
                    .foregroundColor(AppColors.textPrimary)
                    .kerning(2.5)

                Spacer().frame(height: 2)

                Text("Enter PIN from phone")
                    .font(.michroma(7.5))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text("Settings → Watch Pairing PIN")
                    .font(.michroma(7))
                    .foregroundColor(AppColors.textDim)
                    .multilineTextAlignment(.center)

                Spacer().frame(height: 10)

                // PIN slots (animated fill)
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        let filled = i < digits.count
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(filled ? AppColors.surface2 : AppColors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            filled ? AppColors.textSecondary : AppColors.surface2,
                                            lineWidth: filled ? 1.5 : 1
                                        )
                                )
                                .animation(.easeInOut(duration: 0.14), value: filled)
                            if filled {
                                Text(digits[i])
                                    .font(.michroma(16))
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                        .frame(width: 28, height: 34)
                    }
                }

                // Error
                ZStack {
                    if let err = error {
                        Text(err)
                            .font(.michroma(7))
                            .foregroundColor(AppColors.error)
                            .transition(.opacity)
                    }
                }
                .frame(height: 18)
                .padding(.top, 4)
                .animation(.easeInOut(duration: 0.2), value: error)

                Spacer().frame(height: 8)

                // Custom number pad
                NumPad(onDigit: addDigit, onBack: backspace)

                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Logic
    private func addDigit(_ d: String) {
        guard digits.count < 4, !isLoading else { return }
        digits.append(d)
        error = nil
        if digits.count == 4 { submit() }
    }

    private func backspace() {
        guard !digits.isEmpty, !isLoading else { return }
        digits.removeLast()
    }

    private func submit() {
        guard digits.count == 4 else { return }
        let pin = digits.joined()
        isLoading = true
        error = nil

        Swift.Task {
            do {
                _ = try await DataClient.shared.loginWithPin(pin)
                await MainActor.run { onLogin() }
            } catch let err as AppError {
                await MainActor.run {
                    error = err.errorDescription
                    digits = []
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Cannot reach server"
                    digits = []
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Number Pad (mirrors Wear OS _NumPad)
struct NumPad: View {
    let onDigit: (String) -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            numRow(["1", "2", "3"])
            numRow(["4", "5", "6"])
            numRow(["7", "8", "9"])
            HStack(spacing: 4) {
                Color.clear.frame(width: 38, height: 30)
                digitBtn("0")
                backBtn
            }
        }
    }

    private func numRow(_ ds: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(ds, id: \.self) { d in digitBtn(d) }
        }
    }

    private func digitBtn(_ d: String) -> some View {
        Button { onDigit(d) } label: {
            Text(d)
                .font(.michroma(14))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 38, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(AppColors.surface2, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var backBtn: some View {
        Button(action: onBack) {
            Image(systemName: "delete.backward")
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 38, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(AppColors.surface2, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}
