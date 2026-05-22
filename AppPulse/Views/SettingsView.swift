import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General",       systemImage: "gearshape") }
            AISettingsPane()
                .tabItem { Label("AI / Gemini",   systemImage: "sparkles") }
            ToolsSettingsPane()
                .tabItem { Label("Tools",         systemImage: "wrench.and.screwdriver") }
            CIWatchSettingsPane()
                .tabItem { Label("CI Watch",      systemImage: "folder.badge.gearshape") }
            NotificationSettingsPane()
                .tabItem { Label("Notifications", systemImage: "bell") }
            DataManagementPane()
                .tabItem { Label("Data",          systemImage: "cylinder") }
        }
        .frame(width: 480)
    }
}

// MARK: - General

private struct GeneralSettingsPane: View {
    @AppStorage("appearanceMode")        private var appearanceMode       = "system"
    @AppStorage("healthRefreshInterval") private var healthRefreshInterval = 0.0

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Color Scheme", selection: $appearanceMode) {
                    Text("System Default").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.radioGroup)
            }

            Section("API Health Monitoring") {
                Picker("Auto-Refresh", selection: $healthRefreshInterval) {
                    Text("Off").tag(0.0)
                    Text("Every 30 seconds").tag(30.0)
                    Text("Every minute").tag(60.0)
                    Text("Every 5 minutes").tag(300.0)
                }
                if healthRefreshInterval > 0 {
                    Text("Endpoints will be checked automatically in the background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 220)
    }
}

// MARK: - AI / Gemini

private struct AISettingsPane: View {
    @AppStorage("geminiAPIKey") private var apiKey        = ""
    @AppStorage("geminiModel")  private var selectedModel = "gemini-2.5-flash"

    private let models = [
        "gemini-2.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash",
        "gemini-2.0-flash-lite",
        "gemini-1.5-flash",
        "gemini-1.5-pro",
    ]

    var body: some View {
        Form {
            Section {
                LabeledContent("API Key") {
                    SecureField("Paste your key here", text: $apiKey)
                        .frame(maxWidth: 280)
                }
                LabeledContent("Model") {
                    Picker("", selection: $selectedModel) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            } header: {
                HStack {
                    Text("Google Gemini")
                    Spacer()
                    Link("Get API Key →",
                         destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                        .font(.caption)
                }
            } footer: {
                Text("If you get a 404 error when generating, try a different model — availability varies by account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 220)
    }
}

// MARK: - Tools

private struct ToolsSettingsPane: View {
    @AppStorage("jmeterCustomPath")       private var jmeterPath      = ""
    @AppStorage("locustDefaultHost")      private var locustHost      = ""
    @AppStorage("locustDefaultUsers")     private var locustUsers     = 10
    @AppStorage("locustDefaultSpawnRate") private var locustSpawnRate = 1
    @AppStorage("xcodeProjectPath")       private var xcodeProjectPath = ""
    @AppStorage("xcodeScheme")            private var xcodeScheme      = ""
    @AppStorage("xcodeDestination")       private var xcodeDestination = "platform=macOS"

    private let destinationOptions = [
        ("platform=macOS", "macOS"),
        ("platform=iOS Simulator,name=iPhone 16", "iOS Simulator (iPhone 16)"),
        ("custom", "Custom…"),
    ]

    private var isCustomDestination: Bool {
        !destinationOptions.prefix(2).map(\.0).contains(xcodeDestination)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Project / Workspace") {
                    HStack(spacing: 8) {
                        Text(xcodeProjectPath.isEmpty ? "No file selected" : URL(fileURLWithPath: xcodeProjectPath).lastPathComponent)
                            .foregroundStyle(xcodeProjectPath.isEmpty ? .secondary : .primary)
                            .truncationMode(.middle)
                            .frame(maxWidth: 200, alignment: .leading)
                        Button("Browse…") { browseXcodeProject() }.fixedSize()
                        if !xcodeProjectPath.isEmpty {
                            Button { xcodeProjectPath = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                LabeledContent("Scheme") {
                    TextField("e.g. MyApp", text: $xcodeScheme).frame(maxWidth: 220)
                }
                LabeledContent("Destination") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: Binding(
                            get: { isCustomDestination ? "custom" : xcodeDestination },
                            set: { val in
                                if val == "custom" {
                                    xcodeDestination = xcodeDestination.isEmpty ? "platform=macOS" : xcodeDestination
                                } else {
                                    xcodeDestination = val
                                }
                            }
                        )) {
                            ForEach(destinationOptions, id: \.0) { val, label in Text(label).tag(val) }
                        }
                        .labelsHidden()
                        .frame(width: 260)
                        if isCustomDestination {
                            TextField("platform=iOS Simulator,name=…", text: $xcodeDestination)
                                .font(.callout.monospaced())
                                .frame(maxWidth: 260)
                        }
                    }
                }
            } header: {
                Text("Xcode Test Runner")
            } footer: {
                Text("Used by the Run Tests button in the Functional Tests tab. Supports .xcodeproj and .xcworkspace.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 8) {
                    TextField("Auto-detect", text: $jmeterPath)
                        .truncationMode(.middle)
                    Button("Browse…") { browseJMeter() }
                        .fixedSize()
                    if !jmeterPath.isEmpty {
                        Button { jmeterPath = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("JMeter")
            } footer: {
                Text("Leave blank to auto-detect from ~/Desktop/AppPulse/jmeter or Homebrew.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Locust Defaults") {
                LabeledContent("Default Host") {
                    TextField("https://example.com", text: $locustHost)
                        .frame(maxWidth: 240)
                }
                LabeledContent("Default Users") {
                    HStack(spacing: 6) {
                        TextField("", value: $locustUsers, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $locustUsers, in: 1...10000, step: 1)
                            .labelsHidden()
                    }
                }
                LabeledContent("Spawn Rate") {
                    HStack(spacing: 6) {
                        TextField("", value: $locustSpawnRate, format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: $locustSpawnRate, in: 1...1000, step: 1)
                            .labelsHidden()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 420)
    }

    private func browseXcodeProject() {
        let panel = NSOpenPanel()
        panel.title = "Select Xcode Project or Workspace"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a .xcodeproj or .xcworkspace file"
        panel.treatsFilePackagesAsDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            xcodeProjectPath = url.path
        }
    }

    private func browseJMeter() {
        let panel = NSOpenPanel()
        panel.title = "Locate JMeter Binary"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Select the jmeter executable (usually inside bin/)"
        if panel.runModal() == .OK, let url = panel.url {
            jmeterPath = url.path
        }
    }
}

// MARK: - CI Watch

private struct CIWatchSettingsPane: View {
    @AppStorage("ciWatchEnabled")  private var enabled    = false
    @AppStorage("ciWatchFolder")   private var folderPath = ""
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Form {
            Section {
                Toggle("Enable CI Watch Folder", isOn: $enabled)
            } footer: {
                Text("AppPulse monitors a folder and auto-imports .xcresult and .jtl files the moment they appear — no manual drag-and-drop needed.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                HStack(spacing: 8) {
                    Text(folderPath.isEmpty ? "No folder selected" : folderPath)
                        .font(.callout)
                        .foregroundStyle(folderPath.isEmpty ? .secondary : .primary)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Browse…") { browseFolder() }
                        .fixedSize()
                    if !folderPath.isEmpty {
                        Button { folderPath = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Watch Folder")
            } footer: {
                Text("Copy or move .xcresult/.jtl files here from Finder, a CI script, or Xcode Cloud — AppPulse imports them instantly.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!enabled)

            if enabled && !folderPath.isEmpty {
                Section("Status") {
                    LabeledContent("Watching") {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(store.ciWatchActive ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(store.ciWatchActive ? "Active" : "Starting…")
                                .foregroundStyle(store.ciWatchActive ? .green : .orange)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    LabeledContent("Accepts") {
                        Text(".xcresult  ·  .jtl")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        store.reimportAllCIFiles()
                    } label: {
                        Label("Re-import All Files Now", systemImage: "square.and.arrow.down")
                    }
                } footer: {
                    Text("Forces a fresh import of all .xcresult and .jtl files in the watch folder, even ones imported before. Use this after clearing data.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 300)
    }

    private func browseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select CI Watch Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "AppPulse will monitor this folder for new .xcresult and .jtl files"
        if panel.runModal() == .OK, let url = panel.url {
            folderPath = url.path
        }
    }
}

// MARK: - Notifications

private struct NotificationSettingsPane: View {
    @AppStorage("notificationsEnabled")     private var enabled         = false
    @AppStorage("notifyEndpointDown")       private var endpointDown    = true
    @AppStorage("notifyEndpointRecovered")  private var endpointUp      = true
    @AppStorage("notifyGenerationComplete") private var generationDone  = true
    @AppStorage("notifyLocustEvents")       private var locustEvents    = true
    @AppStorage("notifyCIImport")           private var ciImport        = true
    @AppStorage("notifyTestRuns")           private var testRuns        = true
    @AppStorage("slackWebhookURL")          private var slackWebhookURL = ""
    @State private var slackTestSent = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $enabled)
                    .onChange(of: enabled) { _, on in
                        if on { NotificationService.shared.requestPermission() }
                    }
            } footer: {
                Text("AppPulse will send macOS notifications for the events you choose below.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Events") {
                Toggle("Endpoint goes down",          isOn: $endpointDown)
                Toggle("Endpoint recovers",           isOn: $endpointUp)
                Toggle("AI generation completes",     isOn: $generationDone)
                Toggle("Locust test starts/stops",    isOn: $locustEvents)
                Toggle("CI file auto-imported",       isOn: $ciImport)
                Toggle("Test run completes (Xcode / JMeter)", isOn: $testRuns)
            }
            .disabled(!enabled)

            Section {
                LabeledContent("Webhook URL") {
                    TextField("https://hooks.slack.com/…", text: $slackWebhookURL)
                        .frame(maxWidth: 260)
                        .truncationMode(.middle)
                }
                HStack {
                    Button("Send Test Message") {
                        SlackNotifier.post(webhookURL: slackWebhookURL,
                                           text: ":wave: AppPulse is connected to this channel.")
                        slackTestSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { slackTestSent = false }
                    }
                    .disabled(slackWebhookURL.isEmpty)
                    if slackTestSent {
                        Label("Sent!", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Slack Integration")
            } footer: {
                Text("When set, AppPulse posts a summary to Slack after each test run, JMeter run, and API health check. Create an Incoming Webhook in your Slack workspace settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 380)
    }
}

// MARK: - Data Management

private struct DataManagementPane: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirmClear: ClearTarget? = nil
    @State private var exportMessage = ""
    @State private var showImportError = false
    @State private var importErrorMsg = ""

    enum ClearTarget: String, Identifiable {
        var id: String { rawValue }
        case testRuns       = "all functional test runs"
        case jmeterRuns     = "all JMeter runs"
        case locustRuns     = "all Locust run history"
        case generatedSuites = "all AI-generated suites"
        case endpoints      = "all API endpoints and health history"
        case healthHistory  = "API health history (keeps endpoints)"
    }

    var body: some View {
        Form {
            Section {
                clearButton("Clear Functional Test Runs",  icon: "checklist",        target: .testRuns)
                clearButton("Clear JMeter Runs",           icon: "bolt.horizontal",  target: .jmeterRuns)
                clearButton("Clear Locust Run History",    icon: "hare",             target: .locustRuns)
                clearButton("Clear AI Generated Suites",   icon: "sparkles",         target: .generatedSuites)
                clearButton("Clear API Endpoints",         icon: "network",          target: .endpoints)
                clearButton("Clear API Health History",    icon: "clock.arrow.circlepath", target: .healthHistory)
            } header: {
                Text("Clear Data")
            } footer: {
                Text("Permanently removes the selected data. This cannot be undone.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button {
                    exportBackup()
                } label: {
                    Label("Export Backup…", systemImage: "square.and.arrow.up")
                }
                Button {
                    importBackup()
                } label: {
                    Label("Restore from Backup…", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backup saves all runs, health history, and endpoints to a single file. Restoring replaces all current data.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 10)
        .frame(minHeight: 320)
        .confirmationDialog(
            "Are you sure?",
            isPresented: Binding(get: { confirmClear != nil }, set: { if !$0 { confirmClear = nil } }),
            presenting: confirmClear
        ) { target in
            Button("Clear \(target.rawValue.capitalized)", role: .destructive) {
                switch target {
                case .testRuns:        store.clearTestRuns()
                case .jmeterRuns:      store.clearJMeterRuns()
                case .locustRuns:      store.clearLocustRuns()
                case .generatedSuites: store.clearGeneratedSuites()
                case .endpoints:       store.clearEndpoints()
                case .healthHistory:   store.clearHealthHistory()
                }
                confirmClear = nil
            }
            Button("Cancel", role: .cancel) { confirmClear = nil }
        } message: { target in
            Text("This will permanently delete \(target.rawValue). This action cannot be undone.")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMsg)
        }
    }

    private func clearButton(_ title: String, icon: String, target: ClearTarget) -> some View {
        Button(role: .destructive) {
            confirmClear = target
        } label: {
            Label(title, systemImage: icon)
        }
    }

    private func exportBackup() {
        guard let data = store.exportBackup() else { return }
        let panel = NSSavePanel()
        panel.title = "Export AppPulse Backup"
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "AppPulse_Backup_\(f.string(from: Date())).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.title = "Restore AppPulse Backup"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            try store.importBackup(data)
        } catch {
            importErrorMsg = error.localizedDescription
            showImportError = true
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
