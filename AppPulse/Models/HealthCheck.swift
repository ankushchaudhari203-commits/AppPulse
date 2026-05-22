import Foundation

struct HealthCheck: Identifiable, Codable {
    let id: UUID
    var endpoint: String
    var status: HealthStatus
    var responseTime: TimeInterval
    var statusCode: Int?
    var lastChecked: Date
    var errorMessage: String?

    enum HealthStatus: String, Codable {
        case healthy, degraded, down, unknown
    }
}
