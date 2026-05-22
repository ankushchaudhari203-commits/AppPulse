import Foundation

struct TestRun: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var date: Date
    var status: TestStatus
    var duration: TimeInterval
    var totalTests: Int
    var passedTests: Int
    var failedTests: Int
    var skippedTests: Int
    var testCases: [TestCase] = []
    var notes: String = ""

    enum TestStatus: String, Codable {
        case passed, failed, running, pending
    }

    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passedTests) / Double(totalTests) * 100
    }
}

struct TestCase: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var status: TestCaseStatus
    var duration: TimeInterval

    enum TestCaseStatus: String, Codable {
        case passed, failed, skipped
    }
}
