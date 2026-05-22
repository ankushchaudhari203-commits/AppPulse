import SwiftUI
import AppKit
import Charts
import UniformTypeIdentifiers

enum PerfTab { case jmeter, locust, quickTest }

enum LocustSelection: Hashable {
    case live
    case run(UUID)
}

struct PerformanceView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedTab: PerfTab = .jmeter
    @State private var selectedRunID: JMeterRun.ID?
    @State private var locustSelection: LocustSelection = .live
    @State private var searchText = ""
    @State private var showImporter = false
    @State private var importError: String?
    @State private var showError = false
    @State private var showJMeterAlert = false
    @State private var jmeterAlertMsg = ""
    @State private var renameJMeterRun: JMeterRun?
    @State private var renameJMeterText = ""
    @State private var renameLocustRun: LocustRun?
    @State private var renameLocustText = ""
    @State private var showJMeterCLIProgress = false
    @State private var showJMeterQuickSheet  = false
    @AppStorage("jmeterCustomPath") private var jmeterCustomPath = ""

    private var selectedRun: JMeterRun? {
        store.jmeterRuns.first(where: { $0.id == selectedRunID })
            ?? store.jmeterRuns.first
    }

    private var filteredRuns: [JMeterRun] {
        guard !searchText.isEmpty else { return store.jmeterRuns }
        return store.jmeterRuns.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("JMeter").tag(PerfTab.jmeter)
                    Text("Locust").tag(PerfTab.locust)
                    Text("Quick Test").tag(PerfTab.quickTest)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                if selectedTab == .jmeter {
                    jmeterSidebar
                } else if selectedTab == .locust {
                    locustSidebar
                } else {
                    Color.clear
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .navigationTitle("Performance")
            .toolbar {
                if selectedTab == .jmeter {
                    ToolbarItem {
                        Button { launchJMeter() } label: {
                            Label("Launch JMeter", systemImage: "bolt.horizontal")
                        }
                        .help("Open JMeter GUI")
                    }
                    ToolbarItem {
                        Button { pickAndRunJMX() } label: {
                            Label("Run .jmx", systemImage: "play.fill")
                        }
                        .disabled(store.jmeterCLIRunner.isRunning)
                        .help("Run a .jmx file headless and auto-import results")
                    }
                    ToolbarItem {
                        Button { showImporter = true } label: {
                            Label("Import .jtl", systemImage: "plus")
                        }
                    }
                    if let run = selectedRun {
                        ToolbarItem {
                            Button {
                                PDFExporter.export(title: run.name) {
                                    PrintableJMeterRunView(run: run)
                                }
                            } label: {
                                Label("Export PDF", systemImage: "arrow.down.doc")
                            }
                            .keyboardShortcut("e", modifiers: .command)
                            .help("Export run as PDF")
                        }
                        ToolbarItem {
                            Button(role: .destructive) {
                                store.jmeterRuns.removeAll { $0.id == run.id }
                                store.selectedJMeterRunID = nil
                                selectedRunID = nil
                            } label: {
                                Label("Delete Run", systemImage: "trash")
                            }
                        }
                    }
                } else if selectedTab == .locust, case .run(let id) = locustSelection {
                    ToolbarItem {
                        Button(role: .destructive) {
                            store.locustRuns.removeAll { $0.id == id }
                            locustSelection = .live
                        } label: {
                            Label("Delete Run", systemImage: "trash")
                        }
                    }
                }
            }
        } detail: {
            if selectedTab == .quickTest {
                QuickTestPanel()
                    .environmentObject(store)
            } else if selectedTab == .locust {
                switch locustSelection {
                case .live:
                    LocustPanel()
                case .run(let id):
                    if let run = store.locustRuns.first(where: { $0.id == id }) {
                        LocustRunDetailView(run: run)
                    } else {
                        LocustPanel()
                    }
                }
            } else if let run = selectedRun {
                JMeterPanel(run: run, onImport: { showImporter = true })
                    .id(run.id)
                    .navigationTitle(run.name)
            } else {
                JMeterEmptyDetail(onImport: { showImporter = true })
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "jtl") ?? .xml, .xml],
            allowsMultipleSelection: false
        ) { handleImport($0) }
        .alert("Import Failed", isPresented: $showError, presenting: importError) { _ in
            Button("OK", role: .cancel) {}
        } message: { Text($0) }
        .alert("JMeter Not Found", isPresented: $showJMeterAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(jmeterAlertMsg) }
        .alert("Rename JMeter Run", isPresented: Binding(
            get: { renameJMeterRun != nil },
            set: { if !$0 { renameJMeterRun = nil } }
        )) {
            TextField("Run name", text: $renameJMeterText)
            Button("Rename") {
                if let id = renameJMeterRun?.id, !renameJMeterText.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.renameJMeterRun(id: id, name: renameJMeterText.trimmingCharacters(in: .whitespaces))
                }
                renameJMeterRun = nil
            }
            Button("Cancel", role: .cancel) { renameJMeterRun = nil }
        } message: { Text("Enter a new name for this JMeter run.") }
        .alert("Rename Locust Run", isPresented: Binding(
            get: { renameLocustRun != nil },
            set: { if !$0 { renameLocustRun = nil } }
        )) {
            TextField("Run name", text: $renameLocustText)
            Button("Rename") {
                if let id = renameLocustRun?.id, !renameLocustText.trimmingCharacters(in: .whitespaces).isEmpty {
                    store.renameLocustRun(id: id, name: renameLocustText.trimmingCharacters(in: .whitespaces))
                }
                renameLocustRun = nil
            }
            Button("Cancel", role: .cancel) { renameLocustRun = nil }
        } message: { Text("Enter a new name for this Locust run.") }
        .sheet(isPresented: $showJMeterCLIProgress) {
            RunProgressSheet(
                title: "Running JMeter Test",
                icon: "bolt.horizontal",
                phase: store.jmeterCLIRunner.phase,
                outputLines: store.jmeterCLIRunner.outputLines,
                isRunning: store.jmeterCLIRunner.isRunning
            ) {
                store.jmeterCLIRunner.cancel()
                showJMeterCLIProgress = false
            }
            .onReceive(store.jmeterCLIRunner.$isRunning) { running in
                if !running { showJMeterCLIProgress = false }
            }
        }
        .sheet(isPresented: $showJMeterQuickSheet) {
            JMeterQuickSheet { urlString, method, users, rampUp, duration in
                showJMeterQuickSheet  = false
                showJMeterCLIProgress = true
                Task {
                    do { try await store.runJMeterQuick(urlString: urlString, method: method, users: users, rampUp: rampUp, duration: duration) }
                    catch { showJMeterCLIProgress = false }
                }
            } onRunWebSocket: { urlString, message, users, rampUp, duration in
                showJMeterQuickSheet  = false
                showJMeterCLIProgress = true
                Task {
                    do { try await store.runJMeterQuickWebSocket(urlString: urlString, message: message, users: users, rampUp: rampUp, duration: duration) }
                    catch { showJMeterCLIProgress = false }
                }
            }
        }
    }

    // MARK: - Sidebar columns

    @ViewBuilder
    private var jmeterSidebar: some View {
        if store.jmeterRuns.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 52)).foregroundStyle(.secondary)
                Text("No JMeter runs")
                    .font(.headline)
                Text("Import a .jtl results file to get started")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal)
                Button("Import .jtl") { showImporter = true }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary).font(.subheadline)
                    TextField("Search runs", text: $searchText)
                        .textFieldStyle(.plain).font(.subheadline)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.bar)

                Divider()

                if filteredRuns.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28)).foregroundStyle(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedRunID) {
                        ForEach(filteredRuns) { run in
                            JMeterRunRow(run: run)
                                .tag(run.id)
                                .contextMenu {
                                    Button("Rename…") {
                                        renameJMeterRun  = run
                                        renameJMeterText = run.name
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        store.jmeterRuns.removeAll { $0.id == run.id }
                                        if selectedRunID == run.id { selectedRunID = nil }
                                    } label: {
                                        Label("Delete Run", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { offsets in
                            let ids = Set(offsets.map { filteredRuns[$0].id })
                            store.jmeterRuns.removeAll { ids.contains($0.id) }
                            if let sel = selectedRunID, ids.contains(sel) { selectedRunID = nil }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
        }
    }

    @ViewBuilder
    private var locustSidebar: some View {
        List(selection: $locustSelection) {
            LocustLiveRow(dotColor: locustDotColor, statusLabel: locustStatusLabel)
                .tag(LocustSelection.live)

            if !store.locustRuns.isEmpty {
                Section("History") {
                    ForEach(store.locustRuns) { run in
                        LocustRunRow(run: run)
                            .tag(LocustSelection.run(run.id))
                            .contextMenu {
                                Button("Rename…") {
                                    renameLocustRun  = run
                                    renameLocustText = run.name
                                }
                                Divider()
                                Button(role: .destructive) {
                                    store.locustRuns.removeAll { $0.id == run.id }
                                    if locustSelection == .run(run.id) { locustSelection = .live }
                                } label: {
                                    Label("Delete Run", systemImage: "trash")
                                }
                            }
                    }
                    .onDelete { offsets in
                        let ids = Set(offsets.map { store.locustRuns[$0].id })
                        store.locustRuns.removeAll { ids.contains($0.id) }
                        if case .run(let id) = locustSelection, ids.contains(id) {
                            locustSelection = .live
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var locustDotColor: Color {
        if store.locustHasProcess { return .green }
        if store.locustIsRunning  { return .blue }
        return Color.secondary.opacity(0.4)
    }

    private var locustStatusLabel: String {
        if store.locustHasProcess { return "Running" }
        if store.locustIsRunning  { return "Polling" }
        return "Not connected"
    }

    // MARK: - Actions

    private func pickAndRunJMX() {
        let panel = NSOpenPanel()
        panel.title = "Select .jmx Test Plan"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let type = UTType(filenameExtension: "jmx") { panel.allowedContentTypes = [type] }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        showJMeterCLIProgress = true
        Task {
            do {
                try await store.runJMeterCLI(jmxPath: url.path)
                selectedRunID = store.selectedJMeterRunID
            } catch {
                importError = error.localizedDescription
                showError   = true
                showJMeterCLIProgress = false
            }
        }
    }

    private func launchJMeter() {
        if !jmeterCustomPath.isEmpty, FileManager.default.fileExists(atPath: jmeterCustomPath) {
            runJMeter(at: jmeterCustomPath); return
        }
        let home = NSHomeDirectory()
        let candidates = [
            "\(home)/Desktop/AppPulse/jmeter/bin/jmeter",
            "/opt/homebrew/bin/jmeter",
            "/usr/local/bin/jmeter",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            runJMeter(at: path); return
        }
        let shell = Process()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lc", "which jmeter"]
        let pipe = Pipe()
        shell.standardOutput = pipe; shell.standardError = Pipe()
        if (try? shell.run()) != nil {
            shell.waitUntilExit()
            let found = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !found.isEmpty && FileManager.default.fileExists(atPath: found) {
                runJMeter(at: found); return
            }
        }
        jmeterAlertMsg = "JMeter was not found.\n\nExpected location:\n~/Desktop/AppPulse/jmeter/bin/jmeter\n\nMake sure the jmeter folder is inside your AppPulse directory."
        showJMeterAlert = true
    }

    private func runJMeter(at path: String) {
        do {
            let p = Process(); p.executableURL = URL(fileURLWithPath: path); try p.run()
        } catch {
            jmeterAlertMsg = "Failed to launch JMeter: \(error.localizedDescription)"
            showJMeterAlert = true
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription; showError = true
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let samples = try JMeterParser().parse(at: url)
                let run = JMeterRun(id: UUID(),
                                    name: url.deletingPathExtension().lastPathComponent,
                                    importedAt: Date(), samples: samples)
                store.jmeterRuns.insert(run, at: 0)
                selectedRunID = run.id
                store.selectedJMeterRunID = run.id
            } catch {
                importError = error.localizedDescription; showError = true
            }
        }
    }
}




struct JMeterRunRow: View {
    let run: JMeterRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(run.importedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", run.passRate))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(passRateColor(run.passRate).opacity(0.12))
                    .foregroundStyle(passRateColor(run.passRate))
                    .clipShape(Capsule())
            }
            Text("\(run.samples.count) samples")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func passRateColor(_ rate: Double) -> Color {
        if rate >= 95 { return .green }
        if rate >= 80 { return .orange }
        return .red
    }
}

struct JMeterEmptyDetail: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("No run selected")
                .font(.headline)
            Text("Select a run from the list or import a .jtl file")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Import .jtl", action: onImport)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - JMeter Panel

private enum JMeterDetailTab { case overview, stats, charts }

struct JMeterPanel: View {
    let run: JMeterRun
    let onImport: () -> Void
    @EnvironmentObject var store: AppStore
    @State private var detailTab: JMeterDetailTab = .overview
    @State private var notesText: String

    init(run: JMeterRun, onImport: @escaping () -> Void) {
        self.run = run
        self.onImport = onImport
        _notesText = State(initialValue: run.notes)
    }

    var body: some View {
        if run.samples.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                Text("No JMeter results")
                    .font(.headline)
                Text("Import a .jtl file to see load test results")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Import .jtl", action: onImport)
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                Picker("", selection: $detailTab) {
                    Label("Overview", systemImage: "gauge").tag(JMeterDetailTab.overview)
                    Label("Stats",    systemImage: "tablecells").tag(JMeterDetailTab.stats)
                    Label("Charts",   systemImage: "chart.xyaxis.line").tag(JMeterDetailTab.charts)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                switch detailTab {
                case .overview:
                    ScrollView {
                        VStack(spacing: 16) {
                            JMeterOverviewTab(samples: run.samples)
                                .padding(.bottom, 0)
                            NotesCard(text: $notesText)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                    .onChange(of: notesText) { _, value in
                        store.updateJMeterRunNotes(id: run.id, notes: value)
                    }
                case .stats:    JMeterStatsTab(samples: run.samples)
                case .charts:   JMeterChartsView(samples: run.samples)
                }
            }
        }
    }
}

struct JMeterStatChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - JMeter Overview Tab

struct JMeterOverviewTab: View {
    let samples: [JMeterSample]

    private var successCount: Int { samples.filter(\.success).count }
    private var failCount:    Int { samples.count - successCount }
    private var passRate:     Double { samples.isEmpty ? 0 : Double(successCount) / Double(samples.count) * 100 }
    private var avgRT:        Double { samples.isEmpty ? 0 : samples.map(\.responseTime).reduce(0, +) / Double(samples.count) * 1000 }
    private var minRT:        Double { (samples.map(\.responseTime).min() ?? 0) * 1000 }
    private var maxRT:        Double { (samples.map(\.responseTime).max() ?? 0) * 1000 }
    private var avgBytes:     Double { samples.isEmpty ? 0 : Double(samples.map(\.bytes).reduce(0, +)) / Double(samples.count) }
    private var throughput:   Double {
        guard samples.count > 1 else { return 0 }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        let duration = sorted.last!.timestamp.timeIntervalSince(sorted.first!.timestamp)
        return duration > 0 ? Double(samples.count) / duration : 0
    }

    var body: some View {
        VStack(spacing: 20) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                LocustStatCard(
                    label: "Pass Rate",
                    value: String(format: "%.1f%%", passRate),
                    icon: "checkmark.seal.fill",
                    color: passRate >= 95 ? .green : passRate >= 80 ? .orange : .red
                )
                LocustStatCard(
                    label: "Total Samples",
                    value: "\(samples.count)",
                    icon: "list.bullet",
                    color: .blue
                )
                LocustStatCard(
                    label: "Errors",
                    value: "\(failCount)",
                    icon: "xmark.circle.fill",
                    color: failCount > 0 ? .red : .green
                )
            }
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                LocustMetricTile(label: "Avg RT",    value: String(format: "%.0f ms", avgRT))
                LocustMetricTile(label: "Min RT",    value: String(format: "%.0f ms", minRT))
                LocustMetricTile(label: "Max RT",    value: String(format: "%.0f ms", maxRT))
                LocustMetricTile(label: "Throughput",value: String(format: "%.1f/s",  throughput))
                LocustMetricTile(label: "Avg Size",  value: formatBytes(avgBytes))
                LocustMetricTile(label: "Error %",   value: String(format: "%.1f%%", 100 - passRate),
                                 valueColor: failCount > 0 ? .red : .green)
                LocustMetricTile(label: "Passed",    value: "\(successCount)", valueColor: .green)
                LocustMetricTile(label: "Failed",    value: "\(failCount)",
                                 valueColor: failCount > 0 ? .red : .secondary)
            }
            .padding(.horizontal)
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private func formatBytes(_ bytes: Double) -> String {
        if bytes < 1024     { return String(format: "%.0f B",  bytes) }
        if bytes < 1048576  { return String(format: "%.1f KB", bytes / 1024) }
        return                       String(format: "%.1f MB", bytes / 1048576)
    }
}

// MARK: - JMeter Stats Tab

private struct JMeterLabelStat: Identifiable {
    let id = UUID()
    let label:     String
    let count:     Int
    let passCount: Int
    let failCount: Int
    let avgRT:     Double
    let minRT:     Double
    let maxRT:     Double
    var passRate:  Double { count > 0 ? Double(passCount) / Double(count) * 100 : 0 }
}

struct JMeterStatsTab: View {
    let samples: [JMeterSample]

    private var labelStats: [JMeterLabelStat] {
        var grouped: [String: [JMeterSample]] = [:]
        for s in samples { grouped[s.label, default: []].append(s) }
        return grouped.map { label, items in
            JMeterLabelStat(
                label:     label.isEmpty ? "(unnamed)" : label,
                count:     items.count,
                passCount: items.filter(\.success).count,
                failCount: items.filter { !$0.success }.count,
                avgRT:     items.map(\.responseTime).reduce(0, +) / Double(items.count) * 1000,
                minRT:     (items.map(\.responseTime).min() ?? 0) * 1000,
                maxRT:     (items.map(\.responseTime).max() ?? 0) * 1000
            )
        }
        .sorted { $0.count > $1.count }
    }

    var body: some View {
        Table(labelStats) {
            TableColumn("Label") { row in
                Text(row.label).lineLimit(1)
            }
            TableColumn("Samples") {
                Text("\($0.count)").monospacedDigit()
            }
            TableColumn("Pass Rate") { row in
                Text(String(format: "%.1f%%", row.passRate))
                    .monospacedDigit()
                    .foregroundStyle(row.passRate >= 95 ? .green : row.passRate >= 80 ? .orange : .red)
            }
            TableColumn("Failures") { row in
                Text("\(row.failCount)")
                    .monospacedDigit()
                    .foregroundStyle(row.failCount > 0 ? .red : .secondary)
            }
            TableColumn("Avg (ms)") { Text(String(format: "%.0f", $0.avgRT)).monospacedDigit() }
            TableColumn("Min (ms)") { Text(String(format: "%.0f", $0.minRT)).monospacedDigit() }
            TableColumn("Max (ms)") { Text(String(format: "%.0f", $0.maxRT)).monospacedDigit() }
        }
    }
}

struct JMeterSampleRow: View {
    let sample: JMeterSample

    private var rtMs: Double { sample.responseTime * 1000 }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sample.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(sample.success ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(sample.label.isEmpty ? "(unnamed)" : sample.label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(sample.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !sample.responseCode.isEmpty {
                Text(sample.responseCode)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(codeColor.opacity(0.12))
                    .foregroundStyle(codeColor)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(String(format: "%.0f ms", rtMs))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(rtColor)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private var codeColor: Color {
        switch sample.responseCode.prefix(1) {
        case "2": return .green
        case "4": return .orange
        case "5": return .red
        default:  return .secondary
        }
    }

    private var rtColor: Color {
        switch rtMs {
        case ..<300:     return .green
        case 300..<1000: return .orange
        default:          return .red
        }
    }
}

// MARK: - Locust Panel

enum LocustDetailTab { case overview, stats, charts }

struct LocustPanel: View {
    @EnvironmentObject var store: AppStore
    @State private var showConfig = false
    @State private var locustError: String?
    @State private var showLocustError = false
    @State private var savedLocustfile = ""
    @AppStorage("locustDefaultHost") private var savedHost = "http://localhost"
    @State private var detailTab: LocustDetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusDot)
                        .frame(width: 8, height: 8)
                    Text(statusLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if store.locustIsRunning {
                    Button {
                        NSWorkspace.shared.open(URL(string: "http://localhost:8089")!)
                    } label: {
                        Label("Open Web UI", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open Locust web interface in browser")
                }

                if store.locustHasProcess {
                    Button(role: .destructive) { store.stopLocust() } label: {
                        Label("Stop Locust", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else if store.locustIsRunning {
                    Button { store.stopLocustPolling() } label: {
                        Label("Disconnect", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                } else {
                    Button { showConfig = true } label: {
                        Label("Launch Locust", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button { store.startLocustPolling() } label: {
                        Label("Connect", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                    .help("Connect to an already-running Locust instance at localhost:8089")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            if store.locustIsRunning {
                Picker("", selection: $detailTab) {
                    Label("Overview", systemImage: "gauge").tag(LocustDetailTab.overview)
                    Label("Stats",    systemImage: "tablecells").tag(LocustDetailTab.stats)
                    Label("Charts",  systemImage: "chart.xyaxis.line").tag(LocustDetailTab.charts)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)

                Divider()

                switch detailTab {
                case .overview:
                    if let stats = store.locustStats {
                        LocustOverviewTab(stats: stats)
                    } else {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Waiting for Locust data…")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                case .stats:
                    LocustStatsTab(stats: store.locustStats?.stats ?? [])
                case .charts:
                    LocustChartsTab(history: store.locustChartHistory)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "ant.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.secondary)
                    Text("Locust not connected")
                        .font(.headline)
                    Text("Launch Locust with a test script,\nor connect to a running instance at localhost:8089")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 12) {
                        Button("Launch Locust") { showConfig = true }
                            .buttonStyle(.borderedProminent)
                        Button("Connect to Running") { store.startLocustPolling() }
                            .buttonStyle(.bordered)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showConfig) {
            LocustConfigSheet(locustfilePath: $savedLocustfile, host: $savedHost) { path, host, users, spawnRate in
                do {
                    try store.startLocust(locustfilePath: path, host: host, users: users, spawnRate: spawnRate)
                    showConfig = false
                } catch {
                    locustError = error.localizedDescription
                    showLocustError = true
                }
            }
        }
        .alert("Locust Error", isPresented: $showLocustError, presenting: locustError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private var statusDot: Color {
        if store.locustHasProcess { return .green }
        if store.locustIsRunning  { return .blue }
        return Color.secondary.opacity(0.4)
    }

    private var statusLabel: String {
        if store.locustHasProcess { return "Locust running" }
        if store.locustIsRunning  { return "Polling localhost:8089" }
        return "Not connected"
    }
}

// MARK: - Overview Tab

private struct LocustOverviewTab: View {
    let stats: LocustStats

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text(stats.state.capitalized)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(stateColor(stats.state).opacity(0.12))
                        .foregroundStyle(stateColor(stats.state))
                        .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    LocustStatCard(label: "Requests/sec",
                                  value: String(format: "%.1f", stats.currentRPS),
                                  icon: "arrow.up.arrow.down", color: .blue)
                    LocustStatCard(label: "Users",
                                  value: "\(stats.userCount)",
                                  icon: "person.2.fill", color: .purple)
                    LocustStatCard(label: "Fail Ratio",
                                  value: String(format: "%.1f%%", stats.failRatio * 100),
                                  icon: "exclamationmark.triangle.fill",
                                  color: stats.failRatio > 0.05 ? .red : .green)
                }
                .padding(.horizontal)

                if let agg = stats.stats.first(where: { $0.name == "Aggregated" }), agg.numRequests > 0 {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        LocustMetricTile(label: "Avg RT",    value: String(format: "%.0f ms", agg.avgResponseTime))
                        LocustMetricTile(label: "Min RT",    value: String(format: "%.0f ms", agg.minResponseTime))
                        LocustMetricTile(label: "Max RT",    value: String(format: "%.0f ms", agg.maxResponseTime))
                        LocustMetricTile(label: "Median RT", value: String(format: "%.0f ms", agg.medianResponseTime))
                        LocustMetricTile(label: "95th %ile", value: String(format: "%.0f ms", agg.p95))
                        LocustMetricTile(label: "99th %ile", value: String(format: "%.0f ms", agg.p99))
                        LocustMetricTile(label: "Requests",  value: "\(agg.numRequests)")
                        LocustMetricTile(label: "Failures",  value: "\(agg.numFailures)",
                                         valueColor: agg.numFailures > 0 ? .red : .primary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }

    private func stateColor(_ state: String) -> Color {
        switch state.lowercased() {
        case "running":  return .green
        case "spawning": return .orange
        case "stopped":  return .secondary
        default:         return .blue
        }
    }
}

// MARK: - Stats Table Tab

private struct LocustStatsTab: View {
    let stats: [LocustEndpointStat]

    private var endpoints: [LocustEndpointStat] { stats.filter { $0.name != "Aggregated" } }
    private var aggregated: LocustEndpointStat? { stats.first { $0.name == "Aggregated" } }

    var body: some View {
        if endpoints.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tablecells")
                    .font(.system(size: 36)).foregroundStyle(.secondary)
                Text("No requests recorded yet")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Start a test from the Locust Web UI to see per-endpoint stats")
                    .font(.caption).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                Table(endpoints) {
                    TableColumn("Endpoint") { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.name).lineLimit(1)
                            if let m = row.method {
                                Text(m).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    TableColumn("Requests") { Text("\($0.numRequests)").monospacedDigit() }
                    TableColumn("Failures") { row in
                        Text("\(row.numFailures)")
                            .monospacedDigit()
                            .foregroundStyle(row.numFailures > 0 ? .red : .secondary)
                    }
                    TableColumn("Avg (ms)")    { Text(String(format: "%.0f", $0.avgResponseTime)).monospacedDigit() }
                    TableColumn("Min (ms)")    { Text(String(format: "%.0f", $0.minResponseTime)).monospacedDigit() }
                    TableColumn("Max (ms)")    { Text(String(format: "%.0f", $0.maxResponseTime)).monospacedDigit() }
                    TableColumn("Median (ms)") { Text(String(format: "%.0f", $0.medianResponseTime)).monospacedDigit() }
                    TableColumn("95th (ms)")   { Text(String(format: "%.0f", $0.p95)).monospacedDigit() }
                    TableColumn("RPS")         { Text(String(format: "%.1f", $0.currentRPS)).monospacedDigit() }
                }

                if let agg = aggregated {
                    Divider()
                    HStack(spacing: 16) {
                        Text("Aggregated").font(.caption.weight(.semibold))
                        Spacer()
                        AggPill(label: "Reqs",   value: "\(agg.numRequests)")
                        AggPill(label: "Fails",  value: "\(agg.numFailures)", color: agg.numFailures > 0 ? .red : .secondary)
                        AggPill(label: "Avg",    value: String(format: "%.0f ms", agg.avgResponseTime))
                        AggPill(label: "Min",    value: String(format: "%.0f ms", agg.minResponseTime))
                        AggPill(label: "Max",    value: String(format: "%.0f ms", agg.maxResponseTime))
                        AggPill(label: "Median", value: String(format: "%.0f ms", agg.medianResponseTime))
                        AggPill(label: "95th",   value: String(format: "%.0f ms", agg.p95))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
    }
}

private struct AggPill: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 1) {
            Text(value).font(.caption.weight(.semibold)).foregroundStyle(color).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Charts Tab

private struct LocustChartsTab: View {
    let history: [LocustChartPoint]

    var body: some View {
        if history.count < 2 {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 36)).foregroundStyle(.secondary)
                Text("Collecting chart data…")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Charts appear after a few seconds of polling")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    LocustChartCard(title: "Requests / sec", subtitle: "Total throughput over time") {
                        Chart(history) { pt in
                            LineMark(x: .value("Time", pt.time), y: .value("RPS", pt.rps))
                                .foregroundStyle(.blue)
                            AreaMark(x: .value("Time", pt.time), y: .value("RPS", pt.rps))
                                .foregroundStyle(.blue.opacity(0.12))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) {
                                AxisValueLabel(format: .dateTime.hour().minute().second())
                            }
                        }
                    }

                    LocustChartCard(title: "Avg Response Time (ms)", subtitle: "Aggregated average across all endpoints") {
                        Chart(history) { pt in
                            LineMark(x: .value("Time", pt.time), y: .value("ms", pt.avgRT))
                                .foregroundStyle(.purple)
                            AreaMark(x: .value("Time", pt.time), y: .value("ms", pt.avgRT))
                                .foregroundStyle(.purple.opacity(0.12))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) {
                                AxisValueLabel(format: .dateTime.hour().minute().second())
                            }
                        }
                    }

                    LocustChartCard(title: "Active Users", subtitle: "Concurrent virtual users over time") {
                        Chart(history) { pt in
                            LineMark(x: .value("Time", pt.time), y: .value("Users", pt.userCount))
                                .foregroundStyle(.green)
                            AreaMark(x: .value("Time", pt.time), y: .value("Users", Double(pt.userCount)))
                                .foregroundStyle(.green.opacity(0.12))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) {
                                AxisValueLabel(format: .dateTime.hour().minute().second())
                            }
                        }
                    }

                    LocustChartCard(title: "Fail Ratio (%)", subtitle: "Percentage of failed requests over time") {
                        Chart(history) { pt in
                            LineMark(x: .value("Time", pt.time), y: .value("%", pt.failRatio * 100))
                                .foregroundStyle(.red)
                            AreaMark(x: .value("Time", pt.time), y: .value("%", pt.failRatio * 100))
                                .foregroundStyle(.red.opacity(0.12))
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 5)) {
                                AxisValueLabel(format: .dateTime.hour().minute().second())
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct LocustChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            content().frame(height: 160)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Shared small components

struct LocustMetricTile: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Locust Config Sheet

struct LocustConfigSheet: View {
    @Binding var locustfilePath: String
    @Binding var host: String
    let onLaunch: (String, String, Int, Int) -> Void
    @SwiftUI.Environment(\.dismiss) private var dismiss

    @AppStorage("locustDefaultUsers")     private var defaultUsers     = 10
    @AppStorage("locustDefaultSpawnRate") private var defaultSpawnRate = 1
    @State private var users: String     = ""
    @State private var spawnRate: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Launch Locust")
                .font(.title2.weight(.semibold))

            VStack(alignment: .leading, spacing: 6) {
                Text("Test Script (locustfile.py)")
                    .font(.subheadline.weight(.medium))
                HStack {
                    TextField("Path to locustfile.py", text: $locustfilePath)
                        .textFieldStyle(.roundedBorder)
                    Button("Browse…") { pickLocustfile() }
                        .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Target Host")
                    .font(.subheadline.weight(.medium))
                TextField("https://httpbin.org", text: $host)
                    .textFieldStyle(.roundedBorder)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Number of Users")
                        .font(.subheadline.weight(.medium))
                    TextField("10", text: $users)
                        .textFieldStyle(.roundedBorder)
                        .help("Total concurrent virtual users to simulate")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Spawn Rate (users/sec)")
                        .font(.subheadline.weight(.medium))
                    TextField("1", text: $spawnRate)
                        .textFieldStyle(.roundedBorder)
                        .help("How many users to add per second until target is reached")
                }
            }

            Text("Locust starts automatically at localhost:8089 — AppPulse connects and shows live stats.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Launch") {
                    let u = Int(users) ?? defaultUsers
                    let s = Int(spawnRate) ?? defaultSpawnRate
                    defaultUsers     = u
                    defaultSpawnRate = s
                    onLaunch(locustfilePath, host, u, s)
                }
                .buttonStyle(.borderedProminent)
                .disabled(locustfilePath.isEmpty || host.isEmpty)
            }
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            if users.isEmpty     { users     = "\(defaultUsers)" }
            if spawnRate.isEmpty { spawnRate = "\(defaultSpawnRate)" }
        }
    }

    private func pickLocustfile() {
        let panel = NSOpenPanel()
        panel.title = "Select locustfile.py"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let pyType = UTType(filenameExtension: "py") {
            panel.allowedContentTypes = [pyType]
        }
        if panel.runModal() == .OK, let url = panel.url {
            locustfilePath = url.path
        }
    }
}

struct LocustStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Locust Sidebar Rows

private struct LocustLiveRow: View {
    let dotColor: Color
    let statusLabel: String

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(dotColor.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: "ant.fill").font(.system(size: 15)).foregroundStyle(dotColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Monitor").font(.subheadline).fontWeight(.medium)
                HStack(spacing: 4) {
                    Circle().fill(dotColor).frame(width: 6, height: 6)
                    Text(statusLabel).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LocustRunRow: View {
    let run: LocustRun

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.name).font(.subheadline).fontWeight(.medium).lineLimit(1)
            HStack(spacing: 6) {
                Text(run.date.formatted(.relative(presentation: .named)))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                if run.totalRequests > 0 {
                    Text("\(run.totalRequests) reqs")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
            Text(String(format: "%.1f RPS peak  •  %@",
                        run.peakRPS, durationString(run.duration)))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func durationString(_ d: TimeInterval) -> String {
        d < 60 ? String(format: "%.0fs", d) : String(format: "%dm %02ds", Int(d)/60, Int(d)%60)
    }
}

// MARK: - Locust Run Detail (historical)

struct LocustRunDetailView: View {
    let run: LocustRun
    @State private var tab: LocustDetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.name).font(.headline)
                    Text(run.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                RunInfoChip(label: "Host", value: hostShort)
                RunInfoChip(label: "Users", value: "\(run.userCount)")
                RunInfoChip(label: "Duration", value: durationString)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            Picker("", selection: $tab) {
                Label("Overview", systemImage: "gauge").tag(LocustDetailTab.overview)
                Label("Stats",    systemImage: "tablecells").tag(LocustDetailTab.stats)
                Label("Charts",   systemImage: "chart.xyaxis.line").tag(LocustDetailTab.charts)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(.bar)

            Divider()

            switch tab {
            case .overview: LocustRunOverviewTab(run: run)
            case .stats:    LocustStatsTab(stats: run.stats)
            case .charts:   LocustChartsTab(history: run.chartHistory)
            }
        }
    }

    private var hostShort: String {
        run.host
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
    }

    private var durationString: String {
        let d = run.duration
        return d < 60 ? String(format: "%.0fs", d) : String(format: "%dm %02ds", Int(d)/60, Int(d)%60)
    }
}

private struct RunInfoChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.caption.weight(.semibold)).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LocustRunOverviewTab: View {
    let run: LocustRun

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                    LocustStatCard(label: "Peak RPS",
                                  value: String(format: "%.1f", run.peakRPS),
                                  icon: "arrow.up.arrow.down", color: .blue)
                    LocustStatCard(label: "Total Users",
                                  value: "\(run.userCount)",
                                  icon: "person.2.fill", color: .purple)
                    LocustStatCard(label: "Fail Ratio",
                                  value: String(format: "%.1f%%", run.avgFailRatio * 100),
                                  icon: "exclamationmark.triangle.fill",
                                  color: run.avgFailRatio > 0.05 ? .red : .green)
                }
                .padding(.horizontal)

                if let agg = run.aggregated, agg.numRequests > 0 {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        LocustMetricTile(label: "Avg RT",    value: String(format: "%.0f ms", agg.avgResponseTime))
                        LocustMetricTile(label: "Min RT",    value: String(format: "%.0f ms", agg.minResponseTime))
                        LocustMetricTile(label: "Max RT",    value: String(format: "%.0f ms", agg.maxResponseTime))
                        LocustMetricTile(label: "Median RT", value: String(format: "%.0f ms", agg.medianResponseTime))
                        LocustMetricTile(label: "95th %ile", value: String(format: "%.0f ms", agg.p95))
                        LocustMetricTile(label: "99th %ile", value: String(format: "%.0f ms", agg.p99))
                        LocustMetricTile(label: "Requests",  value: "\(agg.numRequests)")
                        LocustMetricTile(label: "Failures",  value: "\(agg.numFailures)",
                                         valueColor: agg.numFailures > 0 ? .red : .primary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - JMeter Quick Test Sheet

struct JMeterQuickSheet: View {
    let onRun:          (String, String, Int, Int, Int) -> Void
    let onRunWebSocket: (String, String, Int, Int, Int) -> Void

    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    @State private var protocol_  = "HTTP"
    @State private var urlString  = ""
    @State private var method     = "GET"
    @State private var message    = "hello"
    @State private var users      = "10"
    @State private var rampUp     = "5"
    @State private var duration   = "30"

    private let methods   = ["GET", "POST", "PUT", "DELETE", "PATCH"]
    private let protocols = ["HTTP", "WebSocket"]

    private var isWebSocket: Bool { protocol_ == "WebSocket" }

    private var isValid: Bool {
        guard let url = URL(string: urlString), url.host != nil else { return false }
        if isWebSocket {
            return url.scheme == "ws" || url.scheme == "wss"
        }
        return url.scheme == "http" || url.scheme == "https"
    }

    private var placeholder: String {
        isWebSocket ? "ws://127.0.0.1:8000/ws" : "https://api.example.com/endpoint"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: isWebSocket ? "antenna.radiowaves.left.and.right" : "bolt.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quick JMeter Test")
                        .font(.headline)
                    Text("AppPulse generates and runs the test plan automatically")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Protocol picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Protocol").font(.subheadline.weight(.medium))
                Picker("", selection: $protocol_) {
                    ForEach(protocols, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: protocol_) { _ in urlString = "" }
            }

            // URL
            VStack(alignment: .leading, spacing: 6) {
                Text(isWebSocket ? "WebSocket URL" : "API URL").font(.subheadline.weight(.medium))
                TextField(placeholder, text: $urlString)
                    .textFieldStyle(.roundedBorder)
            }

            // HTTP Method (HTTP only)
            if !isWebSocket {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HTTP Method").font(.subheadline.weight(.medium))
                    Picker("", selection: $method) {
                        ForEach(methods, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            // Message (WebSocket only)
            if isWebSocket {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message to send").font(.subheadline.weight(.medium))
                    TextField("hello", text: $message)
                        .textFieldStyle(.roundedBorder)
                        .help("Text message sent over the WebSocket connection")
                }
            }

            // Users / Ramp-up / Duration
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Users").font(.subheadline.weight(.medium))
                    TextField("10", text: $users)
                        .textFieldStyle(.roundedBorder)
                        .help("Total concurrent virtual users")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ramp-up (s)").font(.subheadline.weight(.medium))
                    TextField("5", text: $rampUp)
                        .textFieldStyle(.roundedBorder)
                        .help("Seconds to reach full user count")
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration (s)").font(.subheadline.weight(.medium))
                    TextField("30", text: $duration)
                        .textFieldStyle(.roundedBorder)
                        .help("How long to run the test")
                }
            }

            Text(isWebSocket
                 ? "JMeter will open \(users.isEmpty ? "10" : users) WebSocket connections, send '\(message)' and measure round-trip time for \(duration.isEmpty ? "30" : duration)s."
                 : "JMeter will send \(users.isEmpty ? "10" : users) concurrent \(method) requests to your URL for \(duration.isEmpty ? "30" : duration)s, ramping up over \(rampUp.isEmpty ? "5" : rampUp)s.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Spacer()
                Button {
                    let u = Int(users) ?? 10
                    let r = Int(rampUp) ?? 5
                    let d = Int(duration) ?? 30
                    if isWebSocket {
                        onRunWebSocket(urlString, message, u, r, d)
                    } else {
                        onRun(urlString, method, u, r, d)
                    }
                } label: {
                    Label("Run Load Test", systemImage: isWebSocket ? "antenna.radiowaves.left.and.right" : "bolt.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: 480)
    }
}

// MARK: - Quick Test Panel

struct QuickTestPanel: View {
    @EnvironmentObject var store: AppStore

    @State private var protocol_  = "HTTP"
    @State private var urlString  = ""
    @State private var method     = "GET"
    @State private var message    = "hello"
    @State private var users      = "10"
    @State private var rampUp     = "5"
    @State private var duration   = "30"
    @State private var authType   = "None"
    @State private var authValue  = ""
    @State private var authHeader = ""
    @State private var showProgress = false

    private let methods   = ["GET", "POST", "PUT", "DELETE", "PATCH"]
    private let protocols = ["HTTP", "WebSocket"]
    private let authTypes = ["None", "Bearer Token", "API Key", "Basic Auth", "Custom Header"]

    private var isWebSocket: Bool { protocol_ == "WebSocket" }

    private var authHeaderHint: String {
        switch authType {
        case "Bearer Token":  return "Injects: Authorization: Bearer <token>"
        case "API Key":       return "Injects: \(authHeader.isEmpty ? "X-API-Key" : authHeader): <value>"
        case "Basic Auth":    return "Injects: Authorization: Basic base64(username:password)"
        case "Custom Header": return "Injects: \(authHeader.isEmpty ? "<header>" : authHeader): <value>"
        default: return ""
        }
    }

    private var isValid: Bool {
        guard let url = URL(string: urlString), url.host != nil else { return false }
        return isWebSocket
            ? (url.scheme == "ws" || url.scheme == "wss")
            : (url.scheme == "http" || url.scheme == "https")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Image(systemName: isWebSocket ? "antenna.radiowaves.left.and.right" : "bolt.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Quick Load Test")
                            .font(.title3.weight(.bold))
                        Text("No .jmx file needed — AppPulse generates and runs the test plan automatically")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

                Divider()

                // Protocol
                VStack(alignment: .leading, spacing: 8) {
                    Label("Protocol", systemImage: "network")
                        .font(.subheadline.weight(.semibold))
                    Picker("", selection: $protocol_) {
                        ForEach(protocols, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: protocol_) { _ in urlString = "" }
                }

                // URL
                VStack(alignment: .leading, spacing: 8) {
                    Label(isWebSocket ? "WebSocket URL" : "API URL", systemImage: "link")
                        .font(.subheadline.weight(.semibold))
                    TextField(isWebSocket ? "ws://127.0.0.1:8000/ws" : "http://127.0.0.1:8000/", text: $urlString)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }

                // HTTP Method or WS Message
                if isWebSocket {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Message to send", systemImage: "text.bubble")
                            .font(.subheadline.weight(.semibold))
                        TextField("hello", text: $message)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("HTTP Method", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline.weight(.semibold))
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Load Parameters
                VStack(alignment: .leading, spacing: 8) {
                    Label("Load Parameters", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Users").font(.caption).foregroundStyle(.secondary)
                            TextField("10", text: $users)
                                .textFieldStyle(.roundedBorder)
                                .help("Total concurrent virtual users")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ramp-up (s)").font(.caption).foregroundStyle(.secondary)
                            TextField("5", text: $rampUp)
                                .textFieldStyle(.roundedBorder)
                                .help("Seconds to reach full user count")
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Duration (s)").font(.caption).foregroundStyle(.secondary)
                            TextField("30", text: $duration)
                                .textFieldStyle(.roundedBorder)
                                .help("How long to run the test")
                        }
                    }
                }

                // Authentication
                VStack(alignment: .leading, spacing: 8) {
                    Label("Authentication", systemImage: "lock.shield")
                        .font(.subheadline.weight(.semibold))
                    Picker("Auth Type", selection: $authType) {
                        ForEach(authTypes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if authType != "None" {
                        if authType == "API Key" || authType == "Custom Header" {
                            TextField(authType == "API Key" ? "Header name (e.g. X-API-Key)" : "Header name",
                                      text: $authHeader)
                                .textFieldStyle(.roundedBorder)
                        }
                        if authType == "Basic Auth" {
                            TextField("username:password", text: $authValue)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField(authType == "Bearer Token" ? "Paste token here" : "Value",
                                        text: $authValue)
                                .textFieldStyle(.roundedBorder)
                        }
                        Text(authHeaderHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Summary
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text(isWebSocket
                         ? "\(users.isEmpty ? "10" : users) WebSocket connections → send '\(message)' → measure round-trip for \(duration.isEmpty ? "30" : duration)s"
                         : "\(users.isEmpty ? "10" : users) concurrent \(method) requests → \(duration.isEmpty ? "30" : duration)s duration, \(rampUp.isEmpty ? "5" : rampUp)s ramp-up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Run button
                Button {
                    showProgress = true
                    let u = Int(users) ?? 10
                    let r = Int(rampUp) ?? 5
                    let d = Int(duration) ?? 30
                    Task {
                        do {
                            if isWebSocket {
                                try await store.runJMeterQuickWebSocket(urlString: urlString, message: message,
                                    users: u, rampUp: r, duration: d,
                                    authType: authType, authValue: authValue, authHeader: authHeader)
                            } else {
                                try await store.runJMeterQuick(urlString: urlString, method: method,
                                    users: u, rampUp: r, duration: d,
                                    authType: authType, authValue: authValue, authHeader: authHeader)
                            }
                        } catch { }
                        showProgress = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if showProgress {
                            ProgressView().scaleEffect(0.8)
                            Text("Running…")
                        } else {
                            Image(systemName: isWebSocket ? "antenna.radiowaves.left.and.right" : "bolt.fill")
                            Text("Run Load Test")
                        }
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(!isValid || showProgress || store.jmeterCLIRunner.isRunning)

                if showProgress {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.jmeterCLIRunner.outputLines.suffix(6), id: \.self) { line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } label: {
                        Label("Live Output", systemImage: "terminal")
                            .font(.caption.weight(.semibold))
                    }
                }

                if !store.jmeterRuns.isEmpty {
                    Divider()
                    Text("Results appear in the JMeter tab after each run.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .navigationTitle("Quick Test")
    }
}

#Preview {
    PerformanceView()
        .environmentObject(AppStore())
}
