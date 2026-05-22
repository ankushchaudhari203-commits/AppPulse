import Foundation
import Combine

@MainActor
class APIHealthService: ObservableObject {
    static let shared = APIHealthService()

    @Published var endpoints: [APIEndpoint] = []
    @Published var isChecking = false

    private var timer: Timer?

    init() {
        loadDefaultEndpoints()
        startAutoCheck()
    }

    func checkAll() async {
        isChecking = true
        defer { isChecking = false }

        await withTaskGroup(of: (Int, EndpointStatus, Int?).self) { group in
            for (index, endpoint) in endpoints.enumerated() {
                group.addTask {
                    let (status, ms) = await self.check(endpoint)
                    return (index, status, ms)
                }
            }
            for await (index, status, ms) in group {
                endpoints[index].status = status
                endpoints[index].responseMs = ms
            }
        }

        await AppStore.shared.refreshAll()
    }

    func addEndpoint() {
        endpoints.append(APIEndpoint(name: "New Service", url: "https://"))
    }

    private func check(_ endpoint: APIEndpoint) async -> (EndpointStatus, Int?) {
        guard let url = URL(string: endpoint.url) else { return (.unknown, nil) }

        let start = Date()
        do {
            let request = URLRequest(url: url, timeoutInterval: 10)
            let (_, response) = try await URLSession.shared.data(for: request)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            if code >= 200 && code < 300 {
                return (ms > 2000 ? .slow : .up, ms)
            }
            return (.down, ms)
        } catch {
            return (.down, nil)
        }
    }

    private func startAutoCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.checkAll() }
        }
    }

    private func loadDefaultEndpoints() {
        endpoints = [
            APIEndpoint(name: "User Service",         url: "https://example.com/health"),
            APIEndpoint(name: "WebSocket Server",     url: "https://example.com/ws/health")
        ]
    }
}
