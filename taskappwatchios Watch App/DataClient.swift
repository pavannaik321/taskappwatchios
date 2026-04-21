import Foundation

@MainActor
class DataClient {
    static let shared = DataClient()

    private let baseURL = "https://tasktracker-backend-nu.vercel.app/api"

    private var token: String? {
        get { UserDefaults.standard.string(forKey: "watch_token") }
        set { UserDefaults.standard.setValue(newValue, forKey: "watch_token") }
    }

    var isLoggedIn: Bool { token != nil }

    // MARK: - Auth

    func loginWithPin(_ pin: String) async throws -> UserModel {
        let url = URL(string: "\(baseURL)/auth/watch-login")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 15
        req.httpBody = try JSONEncoder().encode(WatchLoginBody(pin: pin))

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw AppError.serverError }
        guard http.statusCode == 200 else {
            throw http.statusCode == 401 ? AppError.expiredPin : AppError.invalidPin
        }

        let body = try JSONDecoder().decode(WatchLoginResponse.self, from: data)
        guard body.success, let tok = body.token else { throw AppError.invalidPin }
        token = tok

        let remote = body.user
        let isoFmt = ISO8601DateFormatter()
        let user = UserModel(
            id:                     remote?.id ?? "",
            displayName:            remote?.displayName ?? "User",
            email:                  remote?.email ?? "",
            plan:                   remote?.plan ?? "free",
            planExpiresAt:          remote?.planExpiresAt.flatMap { isoFmt.date(from: $0) },
            defaultIntervalMinutes: remote?.defaultIntervalMinutes ?? 60,
            workStartHour:          remote?.workStartHour ?? 8,
            workEndHour:            remote?.workEndHour ?? 20
        )

        // Persist user + schedule settings
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "watch_user")
        }
        UserDefaults.standard.set(user.defaultIntervalMinutes, forKey: "watch_interval")
        UserDefaults.standard.set(user.workStartHour,          forKey: "watch_work_start")
        UserDefaults.standard.set(user.workEndHour,            forKey: "watch_work_end")

        return user
    }

    func logout() {
        token = nil
        UserDefaults.standard.removeObject(forKey: "watch_token")
        UserDefaults.standard.removeObject(forKey: "watch_user")
    }

    // MARK: - Cached user

    func currentUser() -> UserModel? {
        guard let data = UserDefaults.standard.data(forKey: "watch_user") else { return nil }
        return try? JSONDecoder().decode(UserModel.self, from: data)
    }

    // MARK: - Tasks

    func fetchTasks(for date: String) async throws -> [TaskItem] {
        guard let token else { throw AppError.notAuthenticated }
        let url = URL(string: "\(baseURL)/tasks?date=\(date)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.serverError
        }
        return try JSONDecoder().decode(TasksResponse.self, from: data).tasks
    }

    func fetchSummary(for date: String) async throws -> DaySummary {
        guard let token else { throw AppError.notAuthenticated }
        let url = URL(string: "\(baseURL)/tasks/summary?date=\(date)")!
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AppError.serverError
        }
        return try JSONDecoder().decode(SummaryResponse.self, from: data).summary
    }

    func createTask(_ body: CreateTaskBody) async throws {
        guard let token else { throw AppError.notAuthenticated }
        let url = URL(string: "\(baseURL)/tasks")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15
        req.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 200 || http.statusCode == 201 else {
            throw AppError.serverError
        }
    }

    // MARK: - Helpers

    static func todayString() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }
}

enum AppError: LocalizedError {
    case notAuthenticated, invalidPin, expiredPin, serverError, cannotReachServer

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:  return "Not logged in"
        case .invalidPin:        return "Invalid PIN"
        case .expiredPin:        return "Expired PIN — get a new one"
        case .serverError:       return "Server error"
        case .cannotReachServer: return "Cannot reach server"
        }
    }
}
