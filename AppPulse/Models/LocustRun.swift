import Foundation

struct LocustRun: Codable, Identifiable {
    let id: UUID
    var name: String
    let date: Date
    let host: String
    let userCount: Int
    let spawnRate: Int
    let duration: TimeInterval
    let stats: [LocustEndpointStat]
    let chartHistory: [LocustChartPoint]

    var aggregated: LocustEndpointStat? { stats.first { $0.name == "Aggregated" } }

    var peakRPS: Double { chartHistory.map(\.rps).max() ?? 0 }

    var totalRequests: Int { aggregated?.numRequests ?? 0 }

    var avgFailRatio: Double {
        guard let agg = aggregated, agg.numRequests > 0 else { return 0 }
        return Double(agg.numFailures) / Double(agg.numRequests)
    }
}
