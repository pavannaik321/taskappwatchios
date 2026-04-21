import SwiftUI

// MARK: - Color Palette — matches Wear OS grayscale theme exactly
struct AppColors {
    static let bg           = Color(hex: "000000") // pure black
    static let surface      = Color(hex: "121212") // dark card
    static let surface2     = Color(hex: "1E1E1E") // slightly lighter card
    static let primary      = Color.white
    static let primaryDk    = Color(hex: "E0E0E0")
    static let accent       = Color.white
    static let textPrimary  = Color.white
    static let textSecondary = Color(hex: "BDBDBD")
    static let textDim      = Color(hex: "616161")
    static let error        = Color(hex: "EF4444")
    static let ring         = Color(hex: "1E1E1E")

    // Grayscale category palette — matches phone + Wear OS
    static let category: [String: Color] = [
        "Work"    : Color.white,
        "Meeting" : Color(hex: "E0E0E0"),
        "Break"   : Color(hex: "BDBDBD"),
        "Learning": Color(hex: "9E9E9E"),
        "Admin"   : Color(hex: "757575"),
        "Personal": Color(hex: "616161"),
        "Exercise": Color(hex: "424242"),
        "Other"   : Color(hex: "303030"),
    ]

    static func forCategory(_ cat: String) -> Color {
        category[cat] ?? .white
    }
}

// MARK: - Hex Color Init
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a: UInt64; let r: UInt64; let g: UInt64; let b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Michroma Font
// To enable: add Michroma-Regular.ttf to Watch App target, then in Info.plist
// add key "Fonts provided by application" = ["Michroma-Regular.ttf"]
extension Font {
    static func michroma(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Michroma-Regular", size: size)
    }
}

// MARK: - Category SF Symbol icons (closest matches to Wear OS Material icons)
func categoryIcon(_ cat: String) -> String {
    switch cat {
    case "Work":     return "briefcase.fill"
    case "Meeting":  return "person.2.fill"
    case "Learning": return "book.fill"
    case "Break":    return "cup.and.saucer.fill"
    case "Personal": return "heart.fill"
    case "Exercise": return "figure.run"
    case "Admin":    return "folder.fill"
    default:         return "tag.fill"
    }
}

// MARK: - Duration label
func durationLabel(from start: Date, to end: Date) -> String {
    let m = Int(end.timeIntervalSince(start) / 60)
    if m <= 0 { return "—" }
    let h = m / 60; let rem = m % 60
    if h > 0 { return rem > 0 ? "\(h)h \(rem)m" : "\(h)h" }
    return "\(m)m"
}

// MARK: - Value clamping helper (avoids name collision with SDK)
func clampValue<T: Comparable>(_ v: T, lo: T, hi: T) -> T { min(max(v, lo), hi) }
