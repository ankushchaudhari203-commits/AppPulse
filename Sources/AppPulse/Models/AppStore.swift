import SwiftUI
import Combine

@MainActor
class AppStore: ObservableObject {
    static let shared = AppStore()

    @Published var selectedEnvironment: AppEnvironment = AppEnvironment.defaults[1]
    @Published var environments: [AppEnvironment] = AppEnvironment.defaults
    @Published var recentRuns: [TestRun] = []
    @Published var reports: [Report] = []
    @Published var issues: [String] = []

    // Summary stats
    @Published var qualityScore: Int = 0
    @Published var functionalStatus: HealthStatus = .unknown
    @Published var functionalPassed: Int = 0
    @Published var functionalFailed: Int = 0
    @Published var performanceStatus: HealthStatus = .unknown
    @Published var performanceSummary: String = "No data yet"
    @Published var apiHealthStatus: HealthStatus = .unknown
    @Published var apiHealthSummary: String = "No data yet"

    var lastUpdated: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    func refreshAll() async {
        // Pull latest state from each service and compute score
        let xcResult  = XCResultParser.shared
        let apiHealth = APIHealthService.shared

        functionalPassed = xcResult.testSuites.flatMap(\.cases).filter(\.passed).count
        functionalFailed = xcResult.testSuites.flatMap(\.cases).filter { !$0.passed }.count
        functionalStatus = functionalFailed == 0 ? .good : functionalFailed < 3 ? .warning : .critical

        let upCount = apiHealth.endpoints.filter { $0.status == .up }.count
        let total   = apiHealth.endpoints.count
        apiHealthStatus  = total == 0 ? .unknown : upCount == total ? .good : upCount > 0 ? .warning : .critical
        apiHealthSummary = total == 0 ? "No endpoints" : "\(upCount)/\(total) responding"

        updateIssues()
        computeScore()
    }

    func generateReport() {
        let report = Report(
            title: "Quality Summary — \(formattedDate)",
            date: formattedDate,
            passRate: qualityScore,
            openIssues: issues.count
        )
        reports.insert(report, at: 0)
    }

    private func updateIssues() {
        var found: [String] = []
        if functionalFailed > 0 { found.append("\(functionalFailed) functional test(s) failing") }
        let downEndpoints = APIHealthService.shared.endpoints.filter { $0.status == .down }
        found.append(contentsOf: downEndpoints.map { "\($0.name) is not responding" })
        issues = found
    }

    private func computeScore() {
        var score = 100
        if functionalFailed > 0 { score -= min(40, functionalFailed * 10) }
        if apiHealthStatus == .critical { score -= 30 }
        else if apiHealthStatus == .warning { score -= 15 }
        qualityScore = max(0, score)
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: Date())
    }
}
