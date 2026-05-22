import Foundation

struct Environment: Identifiable, Codable {
    let id: UUID
    var name: String
    var baseURL: String
    var isActive: Bool

    static let defaults: [Environment] = [
        Environment(id: UUID(), name: "Dev", baseURL: "http://localhost:8080", isActive: true),
        Environment(id: UUID(), name: "Staging", baseURL: "https://staging.example.com", isActive: false),
        Environment(id: UUID(), name: "Production", baseURL: "https://api.example.com", isActive: false)
    ]
}
