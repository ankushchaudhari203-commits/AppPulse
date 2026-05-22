import Foundation

enum TestCaseType: String, Codable, CaseIterable {
    case positive, negative
}

struct GeneratedTestCase: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let title: String
    let type: TestCaseType
    let steps: [String]
    let expectedResult: String
}

struct GeneratedSuite: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let name: String
    let date: Date
    let userStory: String
    let scenarios: String
    let testCases: [GeneratedTestCase]

    var positiveTests: [GeneratedTestCase] { testCases.filter { $0.type == .positive } }
    var negativeTests: [GeneratedTestCase]  { testCases.filter { $0.type == .negative } }
}
