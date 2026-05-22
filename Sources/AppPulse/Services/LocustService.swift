import Foundation
import Combine
import AppKit

@MainActor
class LocustService: ObservableObject {
    static let shared = LocustService()

    @Published var isRunning = false
    @Published var stats: LocustStats?
    @Published var selectedFile: String?

    private var pollTask: Task<Void, Never>?
    private var process: Process?

    func selectFile() {
        let panel = NSOpenPanel()
        panel.message = "Select a Locust file (locustfile.py)"
        panel.prompt = "Select"
        if panel.runModal() == .OK {
            selectedFile = panel.url?.path
        }
    }

    func run(users: Int, spawnRate: Int, duration: Int) async {
        guard let filePath = selectedFile else { return }
        let host = AppStore.shared.selectedEnvironment.wsURL

        isRunning = true
        stats = nil

        let cmd = "locust -f \"\(filePath)\" --host \"\(host)\" --users \(users) --spawn-rate \(spawnRate) --run-time \(duration)m --headless --web-port 8089 &"
        _ = await shell(cmd)

        // Give Locust a moment to start
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        startPolling()
    }

    func stop() {
        pollTask?.cancel()
        _ = Process.run("/usr/bin/pkill", arguments: ["-f", "locust"])
        isRunning = false
    }

    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                await fetchStats()
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func fetchStats() async {
        guard let url = URL(string: "http://localhost:8089/stats/requests") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        guard let statsArr = json["stats"] as? [[String: Any]],
              let aggregate = statsArr.first(where: { ($0["name"] as? String) == "Aggregated" })
        else { return }

        let totalReqs   = (aggregate["num_requests"]  as? Int) ?? 0
        let failures    = (aggregate["num_failures"]  as? Int) ?? 0
        let avgResponse = (aggregate["avg_response_time"] as? Double) ?? 0
        let rps         = (aggregate["current_rps"]   as? Double) ?? 0
        let users       = (json["user_count"]         as? Int) ?? 0

        let successRate = totalReqs > 0
            ? Double(totalReqs - failures) / Double(totalReqs) * 100
            : 100.0

        stats = LocustStats(
            successRate:   successRate,
            avgResponseMs: avgResponse,
            requestsPerSec: rps,
            failureRate:   totalReqs > 0 ? Double(failures) / Double(totalReqs) * 100 : 0,
            currentUsers:  users
        )

        // Stop polling if Locust finished
        if let finished = json["state"] as? String, finished == "stopped" {
            isRunning = false
            pollTask?.cancel()
        }
    }
}
