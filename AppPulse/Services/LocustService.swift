import Foundation
import Combine

// MARK: - Models

struct LocustEndpointStat: Codable, Identifiable {
    var id: String { "\(method ?? "ALL")|\(name)" }
    var name: String
    var method: String?
    var numRequests: Int
    var numFailures: Int
    var avgResponseTime: Double
    var minResponseTime: Double
    var maxResponseTime: Double
    var medianResponseTime: Double
    var currentRPS: Double
    var p95: Double
    var p99: Double

    enum CodingKeys: String, CodingKey {
        case name, method
        case numRequests        = "num_requests"
        case numFailures        = "num_failures"
        case avgResponseTime    = "avg_response_time"
        case minResponseTime    = "min_response_time"
        case maxResponseTime    = "max_response_time"
        case medianResponseTime = "median_response_time"
        case currentRPS         = "current_rps"
        case p95                = "response_time_percentile_0.95"
        case p99                = "response_time_percentile_0.99"
    }
}

struct LocustChartPoint: Identifiable, Codable {
    let id: UUID
    let time: Date
    let rps: Double
    let userCount: Int
    let avgRT: Double
    let failRatio: Double

    init(time: Date, rps: Double, userCount: Int, avgRT: Double, failRatio: Double) {
        id = UUID()
        self.time = time
        self.rps = rps
        self.userCount = userCount
        self.avgRT = avgRT
        self.failRatio = failRatio
    }
}

struct LocustStats: Codable {
    var currentRPS: Double
    var userCount: Int
    var failRatio: Double
    var state: String
    var stats: [LocustEndpointStat]

    enum CodingKeys: String, CodingKey {
        case currentRPS = "total_rps"
        case userCount  = "user_count"
        case failRatio  = "fail_ratio"
        case state, stats
    }
}

// MARK: - Service

class LocustService: ObservableObject {
    @Published var stats: LocustStats?
    @Published var isRunning = false
    @Published var hasProcess = false
    @Published var chartHistory: [LocustChartPoint] = []

    var onRunComplete: ((LocustStats, [LocustChartPoint], Date, String, Int, Int) -> Void)?

    private let baseURL = "http://localhost:8089"
    private var timer: Timer?
    private var process: Process?
    private let maxHistory = 120
    private var pendingUsers: Int = 0
    private var pendingSpawnRate: Int = 0
    private var prevState: String = ""
    private var startedAt: Date?
    private var currentHost: String = ""
    private var currentUserCount: Int = 0
    private var currentSpawnRate: Int = 0

    func startPolling(interval: TimeInterval = 2.0) {
        guard !isRunning else { return }
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.fetchStats() }
        }
    }

    func stopPolling() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func startLocust(locustfilePath: String, host: String, users: Int, spawnRate: Int) throws {
        let bin = try findLocustBinary()
        pendingUsers = users
        pendingSpawnRate = spawnRate
        startedAt = Date()
        currentHost = host
        currentUserCount = users
        currentSpawnRate = spawnRate

        let p = Process()
        p.executableURL = URL(fileURLWithPath: bin)
        p.arguments = ["-f", locustfilePath, "--host", host, "--web-port", "8089"]
        p.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if let startDate = self.startedAt, let finalStats = self.stats {
                    self.onRunComplete?(finalStats, self.chartHistory, startDate,
                                       self.currentHost, self.currentUserCount, self.currentSpawnRate)
                }
                self.hasProcess = false
                self.startedAt = nil
                self.currentHost = ""
                self.currentUserCount = 0
                self.currentSpawnRate = 0
                self.stopPolling()
                self.stats = nil
                self.chartHistory.removeAll()
            }
        }
        try p.run()
        process = p
        hasProcess = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.startPolling()
        }
    }

    func stopLocust() {
        if hasProcess, let startDate = startedAt, let finalStats = stats {
            onRunComplete?(finalStats, chartHistory, startDate, currentHost, currentUserCount, currentSpawnRate)
        }
        startedAt = nil  // prevent terminationHandler from double-saving

        // Force-kill: SIGKILL guarantees the process dies immediately
        if let pid = process?.processIdentifier, pid > 0 {
            Darwin.kill(pid, SIGKILL)
        }
        process?.terminate()
        process = nil
        hasProcess = false
        pendingUsers = 0
        pendingSpawnRate = 0
        currentHost = ""
        currentUserCount = 0
        currentSpawnRate = 0
        if prevState == "running" { NotificationService.shared.notifyLocustStopped() }
        prevState = ""
        stopPolling()
        stats = nil
        chartHistory.removeAll()
    }

    private func findLocustBinary() throws -> String {
        let candidates = [
            "/opt/homebrew/bin/locust",
            "/usr/local/bin/locust",
            "/usr/bin/locust",
            "/Library/Frameworks/Python.framework/Versions/3.13/bin/locust",
            "/Library/Frameworks/Python.framework/Versions/3.12/bin/locust",
            "/Library/Frameworks/Python.framework/Versions/3.11/bin/locust",
            "\(NSHomeDirectory())/.local/bin/locust",
            "\(NSHomeDirectory())/Library/Python/3.13/bin/locust",
            "\(NSHomeDirectory())/Library/Python/3.12/bin/locust",
            "\(NSHomeDirectory())/Library/Python/3.11/bin/locust",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }

        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lc", "which locust"]
        let pipe = Pipe()
        shell.standardOutput = pipe
        shell.standardError = Pipe()
        if (try? shell.run()) != nil {
            shell.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !out.isEmpty && FileManager.default.fileExists(atPath: out) { return out }
        }
        throw LocustError.notFound
    }

    @MainActor
    private func fetchStats() async {
        guard let url = URL(string: "\(baseURL)/stats/requests") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(LocustStats.self, from: data)
            let newState = decoded.state.lowercased()
            if prevState != "running" && newState == "running" {
                NotificationService.shared.notifyLocustStarted()
            }
            prevState = newState
            stats = decoded

            // Auto-start the test if we have pending users and Locust is idle
            if pendingUsers > 0 && decoded.state.lowercased() == "ready" {
                await triggerSwarm(users: pendingUsers, spawnRate: pendingSpawnRate)
                pendingUsers = 0
                pendingSpawnRate = 0
            }

            let aggregated = decoded.stats.first(where: { $0.name == "Aggregated" })
            let point = LocustChartPoint(
                time: Date(),
                rps: decoded.currentRPS,
                userCount: decoded.userCount,
                avgRT: aggregated?.avgResponseTime ?? 0,
                failRatio: decoded.failRatio
            )
            if chartHistory.count >= maxHistory { chartHistory.removeFirst() }
            chartHistory.append(point)
        } catch {
            // Locust may not be fully started yet; silently skip
        }
    }

    @MainActor
    private func triggerSwarm(users: Int, spawnRate: Int) async {
        guard let url = URL(string: "\(baseURL)/swarm") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "user_count=\(users)&spawn_rate=\(spawnRate)".data(using: .utf8)
        _ = try? await URLSession.shared.data(for: request)
    }
}

enum LocustError: LocalizedError {
    case notFound
    var errorDescription: String? {
        "Locust binary not found.\n\nInstall with pip:\n  pip install locust"
    }
}
