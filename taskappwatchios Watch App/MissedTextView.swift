import SwiftUI

// Mirrors Wear OS MissedTextScreen: time context → text field → Save / Cancel
struct MissedTextView: View {
    let startISO: String
    let intervalMinutes: Int
    @ObservedObject var store: TaskStore
    let onSaved: () -> Void

    @State private var text:   String = ""
    @State private var saving: Bool   = false

    private let isoFmt  = ISO8601DateFormatter()
    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()
    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private var startTime: Date { isoFmt.date(from: startISO) ?? Date() }
    private var endTime:   Date { startTime.addingTimeInterval(Double(intervalMinutes) * 60) }
    private var timeLabel: String { "\(timeFmt.string(from: startTime)) – \(timeFmt.string(from: endTime))" }

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Slot time
                Text(timeLabel)
                    .font(.michroma(8.5))
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textDim)

                Spacer().frame(height: 12)

                // Text input — TextField with vertical axis (watchOS 9+)
                TextField("What were you doing?", text: $text, axis: .vertical)
                    .font(.michroma(11))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(AppColors.surface2, lineWidth: 1))
                    )

                Spacer().frame(height: 12)

                // Save button
                Button { save() } label: {
                    ZStack {
                        if saving {
                            ProgressView().progressViewStyle(.circular).tint(.black)
                        } else {
                            Text("Save")
                                .font(.michroma(12))
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(AppColors.primary))
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                .buttonStyle(.plain)

                Spacer().frame(height: 8)

                // Cancel
                Button(action: onSaved) {
                    Text("Cancel")
                        .font(.michroma(9))
                        .foregroundColor(AppColors.textDim)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 16)
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !saving else { return }
        saving = true

        let user = DataClient.shared.currentUser()
        let task = LocalTask(
            id:           UUID().uuidString,
            title:        trimmed,
            category:     "Work",
            startTime:    startTime,
            endTime:      endTime,
            date:         dateFmt.string(from: startTime),
            isQuickEntry: true,
            isSynced:     false,
            userId:       user?.id ?? "guest"
        )

        store.save(task)
        store.syncToServer()
        onSaved()
    }
}
