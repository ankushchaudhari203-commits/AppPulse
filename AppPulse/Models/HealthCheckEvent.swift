import Foundation

struct HealthCheckEvent: Codable, Identifiable {
    let id: UUID
    let date: Date
    let status: HealthCheck.HealthStatus
    let responseTime: TimeInterval
    let statusCode: Int?
}
