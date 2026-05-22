import Foundation
import Combine

class APIHealthService: ObservableObject {
    @Published var checks: [HealthCheck] = []

    func check(endpoints: [String]) async {
        await withTaskGroup(of: HealthCheck.self) { group in
            for endpoint in endpoints {
                group.addTask { await self.probe(endpoint: endpoint) }
            }
            var results: [HealthCheck] = []
            for await check in group {
                results.append(check)
            }
            await MainActor.run { self.checks = results }
        }
    }

    private func probe(endpoint: String) async -> HealthCheck {
        guard let url = URL(string: endpoint) else {
            return HealthCheck(id: UUID(), endpoint: endpoint, status: .unknown,
                               responseTime: 0, statusCode: nil, lastChecked: Date(),
                               errorMessage: "Invalid URL")
        }
        let start = Date()
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            let elapsed = Date().timeIntervalSince(start)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            let status: HealthCheck.HealthStatus = (200..<300).contains(code) ? .healthy : .degraded
            return HealthCheck(id: UUID(), endpoint: endpoint, status: status,
                               responseTime: elapsed, statusCode: code, lastChecked: Date())
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            return HealthCheck(id: UUID(), endpoint: endpoint, status: .down,
                               responseTime: elapsed, statusCode: nil, lastChecked: Date(),
                               errorMessage: error.localizedDescription)
        }
    }
}
