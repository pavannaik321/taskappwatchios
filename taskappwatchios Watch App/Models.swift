import Foundation

// MARK: - Remote TaskItem (from API — uses TaskItem to avoid Swift Task conflict)
struct TaskItem: Identifiable, Codable, Sendable {
    let id: String
    let clientTaskId: String?   // the UUID we sent when creating — used to de-dup against local store
    let title: String
    let description: String?
    let category: String?
    let startTime: String
    let endTime: String
    let date: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case clientTaskId, title, description, category, startTime, endTime, date
    }

    var startDate: Date? { Self.parseISO(startTime) }
    var endDate:   Date? { Self.parseISO(endTime) }

    private static func parseISO(_ str: String) -> Date? {
        let fmtMs = ISO8601DateFormatter()
        fmtMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmtMs.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }

    var durationMinutes: Int {
        guard let s = startDate, let e = endDate else { return 0 }
        return Int(e.timeIntervalSince(s) / 60)
    }

    var timeRangeLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
        let s = startDate.map { fmt.string(from: $0) } ?? "--"
        let e = endDate.map   { fmt.string(from: $0) } ?? "--"
        return "\(s) – \(e)"
    }

    var durationLabel: String {
        let m = durationMinutes; if m <= 0 { return "—" }
        let h = m / 60; let r = m % 60
        if h > 0 { return r > 0 ? "\(h)h \(r)m" : "\(h)h" }
        return "\(m)m"
    }
}

// MARK: - API Response Types
struct TasksResponse:   Codable, Sendable { let success: Bool; let tasks: [TaskItem] }
struct SummaryResponse: Codable, Sendable { let success: Bool; let summary: DaySummary }

struct DaySummary: Codable, Sendable {
    let date: String
    let totalTasks: Int
    let totalMinutes: Int
    let byCategory: [String: Int]
}

struct AuthResponse:   Codable, Sendable { let success: Bool; let token: String }
struct WatchLoginBody: Codable, Sendable { let pin: String }

struct WatchLoginResponse: Codable, Sendable {
    let success: Bool
    let token: String?
    let user: RemoteUser?
}

struct RemoteUser: Codable, Sendable {
    let id: String?
    let displayName: String?
    let email: String?
    let defaultIntervalMinutes: Int?
    let workStartHour: Int?
    let workEndHour: Int?
    let plan: String?
    let planExpiresAt: String?
}

struct CreateTaskBody: Codable, Sendable {
    let id: String              // backend reads this field as clientTaskId for de-dup
    let title: String
    let category: String
    let startTime: String
    let endTime: String
    let date: String
    let isQuickEntry: Bool
    let intervalMinutes: Int
}

// MARK: - Local Task (offline-first storage)
struct LocalTask: Identifiable, Codable, Sendable {
    var id: String
    var title: String
    var category: String
    var startTime: Date
    var endTime: Date
    var date: String
    var isQuickEntry: Bool
    var isSynced: Bool
    var userId: String

    var durationMinutes: Int { Int(endTime.timeIntervalSince(startTime) / 60) }

    var durationLabel: String {
        let m = durationMinutes; if m <= 0 { return "—" }
        let h = m / 60; let r = m % 60
        if h > 0 { return r > 0 ? "\(h)h \(r)m" : "\(h)h" }
        return "\(m)m"
    }

    var timeRangeLabel: String {
        let fmt = DateFormatter(); fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: startTime)) – \(fmt.string(from: endTime))"
    }
}

// MARK: - User Model (stored locally after login)
struct UserModel: Codable, Sendable {
    var id: String
    var displayName: String
    var email: String
    var plan: String
    var planExpiresAt: Date?
    var defaultIntervalMinutes: Int
    var workStartHour: Int
    var workEndHour: Int

    var isPlanExpired: Bool {
        guard let exp = planExpiresAt else { return false }
        return exp < Date()
    }

    var planLabel: String {
        switch plan.lowercased() {
        case "pro":   return "Pro"
        case "track": return "Track"
        default:      return "Free"
        }
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        return letters.isEmpty ? "U" : letters
    }
}
