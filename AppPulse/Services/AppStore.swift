import Foundation
import Combine
import SwiftUI

class AppStore: ObservableObject {
    @Published var testRuns: [TestRun] = []
    @Published var healthChecks: [HealthCheck] = []
    @Published var jmeterRuns: [JMeterRun] = []
    @Published var selectedJMeterRunID: JMeterRun.ID?
    @Published var generatedSuites: [GeneratedSuite] = []
    @Published var locustStats: LocustStats?
    @Published var locustIsRunning = false
    @Published var locustHasProcess = false
    @Published var ciWatchActive = false
    @Published var locustChartHistory: [LocustChartPoint] = []
    @Published var locustRuns: [LocustRun] = []
    @Published var healthHistory: [String: [HealthCheckEvent]] = [:]
    @Published var xcodeRunner    = XcodeBuildRunner()
    @Published var jmeterCLIRunner = JMeterCLIRunner()

    var jmeterSamples: [JMeterSample] {
        let run = jmeterRuns.first(where: { $0.id == selectedJMeterRunID }) ?? jmeterRuns.first
        return run?.samples ?? []
    }
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?

    @Published var monitoredEndpoints: [String] = UserDefaults.standard.stringArray(forKey: "monitoredEndpoints") ?? [] {
        didSet { UserDefaults.standard.set(monitoredEndpoints, forKey: "monitoredEndpoints") }
    }

    private let healthService = APIHealthService()
    private let locustService = LocustService()
    private let ciWatcher = CIWatcherService()
    private var cancellables = Set<AnyCancellable>()
    private var autoRefreshCancellable: AnyCancellable?
    private var prevHealthStatuses: [String: HealthCheck.HealthStatus] = [:]

    private static let appSupportURL: URL = {
        let url = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AppPulse")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    private static var jmeterStorageURL:       URL { appSupportURL.appendingPathComponent("jmeter_runs.json") }
    private static var testRunsStorageURL:      URL { appSupportURL.appendingPathComponent("test_runs.json") }
    private static var generatedSuitesStorageURL: URL { appSupportURL.appendingPathComponent("generated_suites.json") }
    private static var locustRunsStorageURL:    URL { appSupportURL.appendingPathComponent("locust_runs.json") }
    private static var healthHistoryStorageURL: URL { appSupportURL.appendingPathComponent("health_history.json") }

    init() {
        jmeterRuns      = Self.loadJSON(from: Self.jmeterStorageURL)
        testRuns        = Self.loadJSON(from: Self.testRunsStorageURL)
        generatedSuites = Self.loadJSON(from: Self.generatedSuitesStorageURL)
        locustRuns      = Self.loadJSON(from: Self.locustRunsStorageURL)
        if let data = try? Data(contentsOf: Self.healthHistoryStorageURL),
           let history = try? JSONDecoder().decode([String: [HealthCheckEvent]].self, from: data) {
            healthHistory = history
        }
        healthChecks = monitoredEndpoints.map { url in
            HealthCheck(id: UUID(), endpoint: url, status: .unknown,
                        responseTime: 0, statusCode: nil, lastChecked: Date(), errorMessage: nil)
        }
        locustService.$stats
            .receive(on: DispatchQueue.main)
            .assign(to: &$locustStats)
        locustService.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$locustIsRunning)
        locustService.$hasProcess
            .receive(on: DispatchQueue.main)
            .assign(to: &$locustHasProcess)
        locustService.$chartHistory
            .receive(on: DispatchQueue.main)
            .assign(to: &$locustChartHistory)
        locustService.onRunComplete = { [weak self] finalStats, history, startDate, host, userCount, spawnRate in
            guard let self else { return }
            let duration = Date().timeIntervalSince(startDate)
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, HH:mm"
            let run = LocustRun(
                id: UUID(),
                name: "Run \(formatter.string(from: startDate))",
                date: startDate,
                host: host,
                userCount: userCount,
                spawnRate: spawnRate,
                duration: duration,
                stats: finalStats.stats,
                chartHistory: history
            )
            DispatchQueue.main.async { self.locustRuns.insert(run, at: 0) }
        }
        $jmeterRuns
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.global(qos: .background))
            .sink { runs in Self.saveJSON(runs, to: Self.jmeterStorageURL) }
            .store(in: &cancellables)
        $testRuns
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.global(qos: .background))
            .sink { runs in Self.saveJSON(runs, to: Self.testRunsStorageURL) }
            .store(in: &cancellables)
        $generatedSuites
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.global(qos: .background))
            .sink { suites in Self.saveJSON(suites, to: Self.generatedSuitesStorageURL) }
            .store(in: &cancellables)
        $locustRuns
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.global(qos: .background))
            .sink { runs in Self.saveJSON(runs, to: Self.locustRunsStorageURL) }
            .store(in: &cancellables)
        $healthHistory
            .dropFirst()
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.global(qos: .background))
            .sink { history in
                guard let data = try? JSONEncoder().encode(history) else { return }
                try? data.write(to: Self.healthHistoryStorageURL, options: .atomic)
            }
            .store(in: &cancellables)

        // Re-configure auto-refresh whenever UserDefaults change (e.g. Settings pane update)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.setupAutoRefresh()
                self?.setupCIWatcher()
            }
            .store(in: &cancellables)

        ciWatcher.onNewFiles = { [weak self] urls in
            guard let self else { return }
            for url in urls {
                let filename = url.lastPathComponent
                switch url.pathExtension.lowercased() {
                case "xcresult":
                    if let run = try? XCResultParser().parse(at: url) {
                        self.addTestRun(run)
                        self.markCIFileImported(filename)
                        NotificationService.shared.notifyCIFileImported(filename)
                    }
                case "jtl":
                    if let samples = try? JMeterParser().parse(at: url) {
                        let run = JMeterRun(
                            id: UUID(),
                            name: url.deletingPathExtension().lastPathComponent,
                            importedAt: Date(),
                            samples: samples
                        )
                        self.jmeterRuns.insert(run, at: 0)
                        self.markCIFileImported(filename)
                        NotificationService.shared.notifyCIFileImported(filename)
                    }
                default:
                    break
                }
            }
        }

        setupAutoRefresh()
        setupCIWatcher()
    }

    private static func loadJSON<T: Decodable>(from url: URL) -> [T] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([T].self, from: data)
        else { return [] }
        return items
    }

    private static func saveJSON<T: Encodable>(_ items: [T], to url: URL) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func setupAutoRefresh() {
        autoRefreshCancellable?.cancel()
        let interval = UserDefaults.standard.double(forKey: "healthRefreshInterval")
        guard interval > 0 else { return }
        autoRefreshCancellable = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refresh() } }
    }

    private var lastCIWatchPath = ""

    private func setupCIWatcher() {
        ciWatcher.stop()
        guard UserDefaults.standard.bool(forKey: "ciWatchEnabled"),
              let path = UserDefaults.standard.string(forKey: "ciWatchFolder"),
              !path.isEmpty else {
            ciWatchActive = false
            lastCIWatchPath = ""
            return
        }
        ciWatcher.start(watching: URL(fileURLWithPath: path))
        ciWatchActive = ciWatcher.isRunning

        // Prevent duplicate calls within the same session (UserDefaults pings)
        guard ciWatchActive && path != lastCIWatchPath else { return }
        lastCIWatchPath = path

        // Only reset import tracking if the folder itself changed between sessions
        let persistedPath = UserDefaults.standard.string(forKey: "ciWatchLastPath") ?? ""
        if path != persistedPath {
            importedCIFileNames = []
            UserDefaults.standard.set(path, forKey: "ciWatchLastPath")
        }

        importExistingCIFiles()
    }

    var passRate: Double {
        guard !testRuns.isEmpty else { return 0 }
        return testRuns.map(\.passRate).reduce(0, +) / Double(testRuns.count)
    }

    var healthySummary: String {
        let healthy = healthChecks.filter { $0.status == .healthy }.count
        return "\(healthy)/\(healthChecks.count)"
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        if !monitoredEndpoints.isEmpty {
            await healthService.check(endpoints: monitoredEndpoints)
            let order = Dictionary(uniqueKeysWithValues: monitoredEndpoints.enumerated().map { ($1, $0) })
            healthChecks = healthService.checks.sorted {
                (order[$0.endpoint] ?? 0) < (order[$1.endpoint] ?? 0)
            }
            for check in healthChecks {
                let prev = prevHealthStatuses[check.endpoint]
                if let prev, prev != .down, check.status == .down {
                    NotificationService.shared.notifyEndpointDown(check.endpoint)
                } else if prev == .down, check.status == .healthy {
                    NotificationService.shared.notifyEndpointRecovered(check.endpoint)
                }
                prevHealthStatuses[check.endpoint] = check.status

                let event = HealthCheckEvent(
                    id: UUID(),
                    date: check.lastChecked,
                    status: check.status,
                    responseTime: check.responseTime,
                    statusCode: check.statusCode
                )
                var events = healthHistory[check.endpoint] ?? []
                events.append(event)
                if events.count > 200 { events = Array(events.suffix(200)) }
                healthHistory[check.endpoint] = events
            }
        }
        lastUpdated = Date()
        isRefreshing = false
    }

    func addEndpoint(_ url: String) {
        guard !monitoredEndpoints.contains(url) else { return }
        monitoredEndpoints.append(url)
        healthChecks.append(HealthCheck(
            id: UUID(), endpoint: url, status: .unknown,
            responseTime: 0, statusCode: nil, lastChecked: Date(), errorMessage: nil
        ))
    }

    func removeEndpoints(at offsets: IndexSet) {
        let toRemove = Set(offsets.map { monitoredEndpoints[$0] })
        monitoredEndpoints.remove(atOffsets: offsets)
        healthChecks.removeAll { toRemove.contains($0.endpoint) }
        for url in toRemove { healthHistory.removeValue(forKey: url) }
    }

    func startLocustPolling() { locustService.startPolling() }
    func stopLocustPolling()  { locustService.stopPolling() }

    func startLocust(locustfilePath: String, host: String, users: Int, spawnRate: Int) throws {
        try locustService.startLocust(locustfilePath: locustfilePath, host: host, users: users, spawnRate: spawnRate)
    }

    func stopLocust() { locustService.stopLocust() }

    func addTestRun(_ run: TestRun) { testRuns.insert(run, at: 0) }
    func addGeneratedSuite(_ suite: GeneratedSuite) { generatedSuites.insert(suite, at: 0) }

    // MARK: - CI Import tracking (persists across restarts so cleared runs aren't re-imported)

    private var importedCIFileNames: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "importedCIFileNames") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "importedCIFileNames") }
    }

    private func markCIFileImported(_ filename: String) {
        var known = importedCIFileNames
        known.insert(filename)
        importedCIFileNames = known
    }

    func importExistingCIFiles() {
        guard let path = UserDefaults.standard.string(forKey: "ciWatchFolder"), !path.isEmpty else { return }
        let folder = URL(fileURLWithPath: path)
        let urls   = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var known  = importedCIFileNames
        for url in urls {
            let filename = url.lastPathComponent
            guard !known.contains(filename) else { continue }
            switch url.pathExtension.lowercased() {
            case "xcresult":
                if let run = try? XCResultParser().parse(at: url) {
                    addTestRun(run)
                    known.insert(filename)
                }
            case "jtl":
                if let samples = try? JMeterParser().parse(at: url) {
                    let run = JMeterRun(id: UUID(), name: url.deletingPathExtension().lastPathComponent,
                                       importedAt: Date(), samples: samples)
                    jmeterRuns.insert(run, at: 0)
                    known.insert(filename)
                }
            default: break
            }
        }
        importedCIFileNames = known
    }

    func reimportAllCIFiles() {
        importedCIFileNames = []
        importExistingCIFiles()
    }

    func updateTestRunNotes(id: UUID, notes: String) {
        if let idx = testRuns.firstIndex(where: { $0.id == id }) {
            testRuns[idx].notes = notes
        }
    }

    func updateJMeterRunNotes(id: UUID, notes: String) {
        if let idx = jmeterRuns.firstIndex(where: { $0.id == id }) {
            jmeterRuns[idx].notes = notes
        }
    }

    // MARK: - Rename

    func renameTestRun(id: UUID, name: String) {
        if let idx = testRuns.firstIndex(where: { $0.id == id }) { testRuns[idx].name = name }
    }

    func renameJMeterRun(id: UUID, name: String) {
        if let idx = jmeterRuns.firstIndex(where: { $0.id == id }) { jmeterRuns[idx].name = name }
    }

    func renameLocustRun(id: UUID, name: String) {
        if let idx = locustRuns.firstIndex(where: { $0.id == id }) { locustRuns[idx].name = name }
    }

    // MARK: - Clear

    func clearTestRuns() {
        testRuns = []
        Self.saveJSON(testRuns, to: Self.testRunsStorageURL)
    }

    func clearJMeterRuns() {
        jmeterRuns = []
        selectedJMeterRunID = nil
        Self.saveJSON(jmeterRuns, to: Self.jmeterStorageURL)
    }

    func clearLocustRuns() {
        locustRuns = []
        Self.saveJSON(locustRuns, to: Self.locustRunsStorageURL)
    }

    func clearGeneratedSuites() {
        generatedSuites = []
        Self.saveJSON(generatedSuites, to: Self.generatedSuitesStorageURL)
    }

    func clearHealthHistory() {
        healthHistory = [:]
        let empty = try? JSONEncoder().encode([String: [HealthCheckEvent]]())
        try? empty?.write(to: Self.healthHistoryStorageURL, options: .atomic)
    }

    func clearEndpoints() {
        monitoredEndpoints = []
        healthChecks       = []
        healthHistory      = [:]
        prevHealthStatuses = [:]
        let empty = try? JSONEncoder().encode([String: [HealthCheckEvent]]())
        try? empty?.write(to: Self.healthHistoryStorageURL, options: .atomic)
    }

    // MARK: - Backup / Restore

    struct AppBackup: Codable {
        var testRuns:      [TestRun]
        var jmeterRuns:    [JMeterRun]
        var locustRuns:    [LocustRun]
        var healthHistory: [String: [HealthCheckEvent]]
        var endpoints:     [String]
    }

    func exportBackup() -> Data? {
        let backup = AppBackup(
            testRuns:      testRuns,
            jmeterRuns:    jmeterRuns,
            locustRuns:    locustRuns,
            healthHistory: healthHistory,
            endpoints:     monitoredEndpoints
        )
        return try? JSONEncoder().encode(backup)
    }

    func importBackup(_ data: Data) throws {
        let backup = try JSONDecoder().decode(AppBackup.self, from: data)
        testRuns           = backup.testRuns
        jmeterRuns         = backup.jmeterRuns
        locustRuns         = backup.locustRuns
        healthHistory      = backup.healthHistory
        monitoredEndpoints = backup.endpoints
        healthChecks = backup.endpoints.map { url in
            HealthCheck(id: UUID(), endpoint: url, status: .unknown,
                        responseTime: 0, statusCode: nil, lastChecked: Date(), errorMessage: nil)
        }
    }

    // MARK: - Runners

    @MainActor
    func runXcodeTests() async throws {
        let projectPath = UserDefaults.standard.string(forKey: "xcodeProjectPath") ?? ""
        let scheme      = UserDefaults.standard.string(forKey: "xcodeScheme") ?? ""
        let destination = UserDefaults.standard.string(forKey: "xcodeDestination") ?? "platform=macOS"
        let resultURL   = try await xcodeRunner.run(
            projectPath: projectPath, scheme: scheme,
            destination: destination.isEmpty ? "platform=macOS" : destination)
        let run = try XCResultParser().parse(at: resultURL)
        addTestRun(run)
        NotificationService.shared.notifyTestRunComplete(name: run.name, passed: run.passedTests, total: run.totalTests)
        let webhook = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        if !webhook.isEmpty {
            SlackNotifier.postTestRun(webhookURL: webhook, name: run.name,
                                      passed: run.passedTests, total: run.totalTests, passRate: run.passRate)
        }
    }

    @MainActor
    func runJMeterQuickWebSocket(urlString: String, message: String, users: Int, rampUp: Int, duration: Int,
                                 authType: String = "None", authValue: String = "", authHeader: String = "") async throws {
        let exec   = resolvedJMeterPath()
        let jmxURL = try jmeterCLIRunner.generateWebSocketJMX(urlString: urlString, message: message,
                                                               users: users, rampUp: rampUp, duration: duration,
                                                               authType: authType, authValue: authValue, authHeader: authHeader)
        let jtlURL = try await jmeterCLIRunner.run(jmxPath: jmxURL.path, jmeterExecutable: exec)
        let samples = try JMeterParser().parse(at: jtlURL)
        let host    = URL(string: urlString)?.host ?? urlString
        let name    = "WS Quick Test – \(host)"
        let run     = JMeterRun(id: UUID(), name: name, importedAt: Date(), samples: samples)
        jmeterRuns.insert(run, at: 0)
        selectedJMeterRunID = run.id
        NotificationService.shared.notifyJMeterComplete(name: run.name, passRate: run.passRate, samples: run.samples.count)
        let webhook = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        if !webhook.isEmpty {
            SlackNotifier.postJMeter(webhookURL: webhook, name: run.name,
                                     passRate: run.passRate, samples: run.samples.count,
                                     avgRT: run.avgResponseTime)
        }
    }

    @MainActor
    func runJMeterQuick(urlString: String, method: String, users: Int, rampUp: Int, duration: Int,
                        authType: String = "None", authValue: String = "", authHeader: String = "") async throws {
        let exec   = resolvedJMeterPath()
        let jmxURL = try jmeterCLIRunner.generateJMX(urlString: urlString, method: method,
                                                      users: users, rampUp: rampUp, duration: duration,
                                                      authType: authType, authValue: authValue, authHeader: authHeader)
        let jtlURL = try await jmeterCLIRunner.run(jmxPath: jmxURL.path, jmeterExecutable: exec)
        let samples = try JMeterParser().parse(at: jtlURL)
        let host    = URL(string: urlString)?.host ?? urlString
        let name    = "Quick Test – \(host)"
        let run     = JMeterRun(id: UUID(), name: name, importedAt: Date(), samples: samples)
        jmeterRuns.insert(run, at: 0)
        selectedJMeterRunID = run.id
        NotificationService.shared.notifyJMeterComplete(name: run.name, passRate: run.passRate, samples: run.samples.count)
        let webhook = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        if !webhook.isEmpty {
            SlackNotifier.postJMeter(webhookURL: webhook, name: run.name,
                                     passRate: run.passRate, samples: run.samples.count,
                                     avgRT: run.avgResponseTime)
        }
    }

    @MainActor
    func runJMeterCLI(jmxPath: String) async throws {
        let exec   = resolvedJMeterPath()
        let jtlURL = try await jmeterCLIRunner.run(jmxPath: jmxPath, jmeterExecutable: exec)
        let samples = try JMeterParser().parse(at: jtlURL)
        let name    = URL(fileURLWithPath: jmxPath).deletingPathExtension().lastPathComponent
        let run     = JMeterRun(id: UUID(), name: name, importedAt: Date(), samples: samples)
        jmeterRuns.insert(run, at: 0)
        selectedJMeterRunID = run.id
        NotificationService.shared.notifyJMeterComplete(name: run.name, passRate: run.passRate, samples: run.samples.count)
        let webhook = UserDefaults.standard.string(forKey: "slackWebhookURL") ?? ""
        if !webhook.isEmpty {
            SlackNotifier.postJMeter(webhookURL: webhook, name: run.name,
                                     passRate: run.passRate, samples: run.samples.count,
                                     avgRT: run.avgResponseTime)
        }
    }

    func resolvedJMeterPath() -> String {
        let custom = UserDefaults.standard.string(forKey: "jmeterCustomPath") ?? ""
        if !custom.isEmpty && FileManager.default.isExecutableFile(atPath: custom) { return custom }
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Desktop/AppPulse/jmeter/bin/jmeter",
            "/opt/homebrew/bin/jmeter",
            "/usr/local/bin/jmeter",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/local/bin/jmeter"
    }
}
