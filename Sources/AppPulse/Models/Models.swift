import SwiftUI

// MARK: - Health Status

enum HealthStatus {
    case good, warning, critical, unknown

    var color: Color {
        switch self {
        case .good:    return .green
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .good:    return "Good"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Test Models

struct TestRun: Identifiable {
    let id = UUID()
    let name: String
    let tool: String
    let date: String
    let passed: Bool
}

struct TestSuite: Identifiable {
    let id = UUID()
    let name: String
    let cases: [TestCase]

    var passed: Int { cases.filter(\.passed).count }
    var total: Int { cases.count }
    var allPassed: Bool { cases.allSatisfy(\.passed) }
}

struct TestCase: Identifiable {
    let id = UUID()
    let name: String
    let passed: Bool
    let duration: String
    let failureMessage: String?
}

// MARK: - Performance Models

struct JMeterResult {
    let successRate: Double
    let avgResponseMs: Double
    let requestsPerSec: Double
    let errorRate: Double
}

struct LocustStats {
    let successRate: Double
    let avgResponseMs: Double
    let requestsPerSec: Double
    let failureRate: Double
    let currentUsers: Int
}

// MARK: - API Health Models

struct APIEndpoint: Identifiable {
    let id = UUID()
    var name: String
    var url: String
    var status: EndpointStatus = .unknown
    var responseMs: Int?
}

enum EndpointStatus {
    case up, down, slow, unknown

    var color: Color {
        switch self {
        case .up:      return .green
        case .down:    return .red
        case .slow:    return .orange
        case .unknown: return .gray
        }
    }

    var label: String {
        switch self {
        case .up:      return "Responding"
        case .down:    return "Not responding"
        case .slow:    return "Slow"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Environment Model

struct AppEnvironment: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var httpURL: String
    var wsURL: String

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: AppEnvironment, rhs: AppEnvironment) -> Bool { lhs.id == rhs.id }

    static let defaults: [AppEnvironment] = [
        AppEnvironment(name: "Local", httpURL: "http://localhost:8080", wsURL: "ws://localhost:8080/ws"),
        AppEnvironment(name: "Staging", httpURL: "https://staging.example.com", wsURL: "wss://staging.example.com/ws"),
        AppEnvironment(name: "Production", httpURL: "https://example.com", wsURL: "wss://example.com/ws")
    ]
}

// MARK: - Report Model

struct Report: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let passRate: Int
    let openIssues: Int

    func exportPDF() { /* Phase 2 */ }
    func exportCSV() { /* Phase 2 */ }
}
