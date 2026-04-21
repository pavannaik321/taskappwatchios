import SwiftUI

// Mirrors Wear OS QuickTaskScreen: 2×3 category grid → one tap → confirmation
fileprivate struct QCat { let name: String; let icon: String; let color: Color }

private let qCats: [QCat] = [
    QCat(name: "Work",     icon: "briefcase.fill",     color: Color.white),
    QCat(name: "Meeting",  icon: "person.2.fill",       color: Color(hex: "E0E0E0")),
    QCat(name: "Learning", icon: "book.fill",            color: Color(hex: "BDBDBD")),
    QCat(name: "Break",    icon: "cup.and.saucer.fill", color: Color(hex: "9E9E9E")),
    QCat(name: "Personal", icon: "heart.fill",           color: Color(hex: "757575")),
    QCat(name: "Exercise", icon: "figure.run",           color: Color(hex: "616161")),
]

struct QuickTaskView: View {
    let startISO: String
    let intervalMinutes: Int
    @ObservedObject var store: TaskStore
    let onSaved: (String, String, String) -> Void

    @State private var logged:   String? = nil
    @State private var saving:   Bool    = false
    @State private var checkScale: CGFloat = 0

    private let isoFmt = ISO8601DateFormatter()

    var body: some View {
        Group {
            if let cat = logged {
                confirmView(cat: cat)
            } else {
                gridView
            }
        }
        .background(AppColors.bg)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Category grid
    private var gridView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 10)

            // Header
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.primary)
                Text("Quick Log")
                    .font(.michroma(12))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 14)

            Text("Tap to log 1 session")
                .font(.michroma(8))
                .foregroundColor(AppColors.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.top, 2)

            Spacer().frame(height: 12)

            // 2-column grid
            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
            LazyVGrid(columns: cols, spacing: 12) {
                ForEach(qCats, id: \.name) { cat in
                    QCatTile(cat: cat) { log(cat.name) }
                }
            }
            .padding(.horizontal, 14)

            Spacer()
        }
    }

    // MARK: - Confirmation (mirrors Wear OS _buildConfirm)
    private func confirmView(cat: String) -> some View {
        let qc = qCats.first(where: { $0.name == cat }) ?? qCats[0]
        return VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(qc.color.opacity(0.15))
                    .overlay(Circle().strokeBorder(qc.color, lineWidth: 2))
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(qc.color)
            }
            .scaleEffect(checkScale)
            .animation(.interpolatingSpring(stiffness: 120, damping: 8), value: checkScale)

            Spacer().frame(height: 10)

            Text(qc.name)
                .font(.michroma(15))
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Saving…")
                .font(.michroma(9))
                .foregroundColor(AppColors.textSecondary)

            Spacer()
        }
    }

    // MARK: - Log action
    private func log(_ catName: String) {
        guard !saving else { return }
        saving = true
        logged = catName

        // Animate check
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            checkScale = 1.0
        }

        let start = isoFmt.date(from: startISO) ?? Date().addingTimeInterval(Double(-intervalMinutes) * 60)
        let end   = start.addingTimeInterval(Double(intervalMinutes) * 60)
        let fmt   = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        let user  = DataClient.shared.currentUser()

        let task = LocalTask(
            id:           UUID().uuidString,
            title:        catName,
            category:     catName,
            startTime:    start,
            endTime:      end,
            date:         fmt.string(from: start),
            isQuickEntry: true,
            isSynced:     false,
            userId:       user?.id ?? "guest"
        )

        store.save(task)
        store.syncToServer()

        let sISO = isoFmt.string(from: start)
        let eISO = isoFmt.string(from: end)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            onSaved(catName, sISO, eISO)
        }
    }
}

// MARK: - Category tile (press animation)
fileprivate struct QCatTile: View {
    let cat: QCat
    let onTap: () -> Void

    @State private var pressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.08, dampingFraction: 0.6)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation { pressed = false }
                onTap()
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: cat.icon)
                    .font(.system(size: 16))
                    .foregroundColor(cat.color)
                Text(cat.name.count > 6 ? String(cat.name.prefix(5)) + "." : cat.name)
                    .font(.michroma(9))
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(cat.color.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(cat.color.opacity(0.30), lineWidth: 1))
            )
            .scaleEffect(pressed ? 0.91 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
