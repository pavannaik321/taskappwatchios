import SwiftUI

// Mirrors Wear OS AddTaskScreen: category grid → title → time pickers → save
private struct Cat {
    let name: String; let icon: String; let color: Color
}

private let kCats: [Cat] = [
    Cat(name: "Work",     icon: "briefcase.fill",      color: Color.white),
    Cat(name: "Meeting",  icon: "person.2.fill",        color: Color(hex: "E0E0E0")),
    Cat(name: "Learning", icon: "book.fill",             color: Color(hex: "BDBDBD")),
    Cat(name: "Break",    icon: "cup.and.saucer.fill",  color: Color(hex: "9E9E9E")),
    Cat(name: "Personal", icon: "heart.fill",            color: Color(hex: "757575")),
    Cat(name: "Exercise", icon: "figure.run",            color: Color(hex: "616161")),
]

struct AddTaskView: View {
    let startISO: String
    @ObservedObject var store: TaskStore
    let onSaved: (String, String, String) -> Void // (title, startISO, endISO)

    @State private var category:  String = "Work"
    @State private var titleText: String = ""
    @State private var startTime: Date
    @State private var endTime:   Date
    @State private var saving:    Bool   = false

    private let isoFmt = ISO8601DateFormatter()

    init(startISO: String, store: TaskStore, onSaved: @escaping (String, String, String) -> Void) {
        self.startISO = startISO
        self.store = store
        self.onSaved = onSaved
        let now = Date()
        let parsed = ISO8601DateFormatter().date(from: startISO) ?? now.addingTimeInterval(-1800)
        self._startTime = State(initialValue: parsed)
        self._endTime   = State(initialValue: now)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 8)

                // ── Category grid (3 × 2) ──────────────────────────
                AddSectionLabel("CATEGORY")
                Spacer().frame(height: 7)

                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(kCats, id: \.name) { cat in
                        let sel = category == cat.name
                        Button { category = cat.name } label: {
                            VStack(spacing: 3) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 13))
                                    .foregroundColor(sel ? cat.color : AppColors.textDim)
                                Text(cat.name.count > 6 ? String(cat.name.prefix(5)) + "." : cat.name)
                                    .font(.michroma(7.5))
                                    .fontWeight(.semibold)
                                    .foregroundColor(sel ? cat.color : AppColors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(sel ? cat.color.opacity(0.22) : AppColors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9)
                                            .strokeBorder(sel ? cat.color : AppColors.surface2,
                                                          lineWidth: sel ? 1.5 : 1)
                                    )
                                    .animation(.easeInOut(duration: 0.16), value: sel)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer().frame(height: 14)

                // ── Title (optional) ───────────────────────────────
                AddSectionLabel("TITLE (OPTIONAL)")
                Spacer().frame(height: 7)

                let selCat = kCats.first(where: { $0.name == category }) ?? kCats[0]
                HStack {
                    Image(systemName: selCat.icon)
                        .font(.system(size: 12))
                        .foregroundColor(selCat.color)
                        .padding(.leading, 10)
                    TextField(selCat.name, text: $titleText)
                        .font(.michroma(10))
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.vertical, 4)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppColors.surface2, lineWidth: 1))
                )

                Spacer().frame(height: 14)

                // ── Time row ───────────────────────────────────────
                AddSectionLabel("TIME")
                Spacer().frame(height: 7)

                HStack(spacing: 7) {
                    TimeChip(label: "Start", date: $startTime)
                    TimeChip(label: "End",   date: $endTime)
                }

                Spacer().frame(height: 14)

                // ── Duration badge ─────────────────────────────────
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "timer").font(.system(size: 10)).foregroundColor(AppColors.primary)
                        Text(durationLabel(from: startTime, to: endTime))
                            .font(.michroma(9))
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(AppColors.primary.opacity(0.10))
                            .overlay(Capsule().strokeBorder(AppColors.primary.opacity(0.25), lineWidth: 1))
                    )
                    Spacer()
                }

                Spacer().frame(height: 18)

                // ── Save button ────────────────────────────────────
                Button { save() } label: {
                    ZStack {
                        if saving {
                            ProgressView().progressViewStyle(.circular).tint(.white)
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                                Text("Save").font(.michroma(12)).fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDk],
                                startPoint: .leading, endPoint: .trailing))
                            .shadow(color: AppColors.primary.opacity(0.4), radius: 12, y: 4)
                    )
                }
                .disabled(saving)
                .buttonStyle(.plain)

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 14)
        }
        .background(AppColors.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard !saving else { return }
        saving = true
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? category : titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let fmt   = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let user  = DataClient.shared.currentUser()

        let task = LocalTask(
            id:           UUID().uuidString,
            title:        title,
            category:     category,
            startTime:    startTime,
            endTime:      endTime,
            date:         fmt.string(from: startTime),
            isQuickEntry: false,
            isSynced:     false,
            userId:       user?.id ?? "guest"
        )

        store.save(task)
        store.syncToServer()

        let sISO = isoFmt.string(from: startTime)
        let eISO = isoFmt.string(from: endTime)
        onSaved(title, sISO, eISO)
    }
}

// MARK: - Time chip (tap to open DatePicker sheet)
struct TimeChip: View {
    let label: String
    @Binding var date: Date

    @State private var showPicker = false

    private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
    }()

    var body: some View {
        Button { showPicker = true } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.michroma(7))
                    .foregroundColor(AppColors.textDim)
                Text(timeFmt.string(from: date))
                    .font(.michroma(10))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            DatePicker("", selection: $date, displayedComponents: [.hourAndMinute])
                .datePickerStyle(.wheel)
                .labelsHidden()
                .background(AppColors.bg)
        }
    }
}

// MARK: - Section label (matches Wear OS _SectionLabel)
struct AddSectionLabel: View {
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
