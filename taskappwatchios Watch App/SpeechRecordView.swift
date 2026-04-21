import SwiftUI

// Voice/dictation entry screen.
// On watchOS the system keyboard has a built-in mic button for dictation —
// auto-focusing the TextField opens that keyboard immediately.
struct SpeechRecordView: View {
    let startISO: String
    let intervalMinutes: Int
    @ObservedObject var store: TaskStore
    let onSaved: (String, String, String) -> Void

    @State private var transcript: String = ""
    @State private var saving:     Bool   = false
    @FocusState private var focused: Bool

    private let isoFmt  = ISO8601DateFormatter()
    private let isoFmtMs: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            if saving {
                savingView
            } else {
                mainContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        // Auto-open the keyboard (with dictation) as soon as screen appears
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focused = true
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // ── Mic icon ───────────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(AppColors.surface)
                    .overlay(Circle().strokeBorder(AppColors.surface2, lineWidth: 2))
                    .frame(width: 52, height: 52)
                Image(systemName: transcript.isEmpty ? "mic.fill" : "mic.badge.plus")
                    .font(.system(size: 20))
                    .foregroundColor(transcript.isEmpty ? AppColors.textSecondary : AppColors.primary)
            }

            Spacer().frame(height: 10)

            // ── Hidden TextField — focused state triggers watchOS keyboard+mic ──
            TextField("Speak or type…", text: $transcript, axis: .vertical)
                .font(.michroma(10))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(1...3)
                .focused($focused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                focused ? AppColors.primary.opacity(0.5) : AppColors.surface2,
                                lineWidth: 1))
                )
                .padding(.horizontal, 14)

            Spacer().frame(height: 6)

            Text(transcript.isEmpty ? "Tap field → tap mic to dictate" : " ")
                .font(.michroma(7.5))
                .foregroundColor(AppColors.textDim)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 12)

            // ── Save button (enabled once transcript exists) ────────────
            Button { save() } label: {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    Text("Save").font(.michroma(12)).fontWeight(.bold)
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                   ? AppColors.surface2
                                   : AppColors.primary)
                )
            }
            .disabled(transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            Spacer()
        }
    }

    // MARK: - Saving overlay

    private var savingView: some View {
        VStack(spacing: 10) {
            ProgressView().progressViewStyle(.circular)
            Text("Saving…")
                .font(.michroma(9))
                .foregroundColor(AppColors.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Save

    private func save() {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !saving else { return }
        saving = true
        focused = false

        let start = isoFmtMs.date(from: startISO) ?? isoFmt.date(from: startISO)
                    ?? Date().addingTimeInterval(Double(-intervalMinutes) * 60)
        let end   = start.addingTimeInterval(Double(intervalMinutes) * 60)
        let user  = DataClient.shared.currentUser()

        let task = LocalTask(
            id:           UUID().uuidString,
            title:        trimmed,
            category:     "Work",
            startTime:    start,
            endTime:      end,
            date:         dateFmt.string(from: start),
            isQuickEntry: true,
            isSynced:     false,
            userId:       user?.id ?? "guest"
        )

        store.save(task)
        store.syncToServer()

        let sISO = isoFmt.string(from: start)
        let eISO = isoFmt.string(from: end)
        onSaved(trimmed, sISO, eISO)
    }
}
