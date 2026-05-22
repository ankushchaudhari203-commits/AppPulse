import SwiftUI

struct PerformanceView: View {
    @StateObject private var jmeter = JMeterParser.shared
    @StateObject private var locust = LocustService.shared

    @State private var selectedTool: LoadTool = .jmeter
    @State private var userCount: Double = 100
    @State private var duration: Double = 5

    enum LoadTool: String, CaseIterable {
        case jmeter = "JMeter (HTTP)"
        case locust = "Locust (WebSocket)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Performance")
                    .font(.largeTitle).bold()
                Text("How does the app behave under heavy usage?")
                    .foregroundStyle(.secondary)

                // Config Panel
                GroupBox("Test Configuration") {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Tool", selection: $selectedTool) {
                            ForEach(LoadTool.allCases, id: \.self) { tool in
                                Text(tool.rawValue).tag(tool)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack {
                            Text("Simulated Users: \(Int(userCount))")
                            Slider(value: $userCount, in: 10...1000, step: 10)
                        }

                        HStack {
                            Text("Duration: \(Int(duration)) min")
                            Slider(value: $duration, in: 1...30, step: 1)
                        }

                        if selectedTool == .jmeter {
                            HStack {
                                Text("Test Plan (.jmx):")
                                Text(jmeter.selectedFile ?? "None selected")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Browse") { jmeter.selectFile() }
                            }
                        } else {
                            HStack {
                                Text("Locust File:")
                                Text(locust.selectedFile ?? "None selected")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Browse") { locust.selectFile() }
                            }
                        }

                        HStack {
                            Spacer()
                            Button {
                                Task { await runTest() }
                            } label: {
                                Label("Run Test", systemImage: "play.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isRunning)

                            if isRunning {
                                Button {
                                    stopTest()
                                } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }
                    }
                    .padding()
                }

                // Live Stats
                if isRunning || hasResults {
                    GroupBox("Results") {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                MetricCard(title: "Success Rate", value: successRate, unit: "%", color: successColor)
                                MetricCard(title: "Avg Response", value: avgResponse, unit: "ms", color: .blue)
                                MetricCard(title: "Requests/sec", value: requestsPerSec, unit: "rps", color: .purple)
                                MetricCard(title: "Errors", value: errorRate, unit: "%", color: .red)
                            }

                            if isRunning {
                                ProgressView("Test running... \(Int(userCount)) users active")
                                    .frame(maxWidth: .infinity)
                            }

                            if let summary = resultSummary {
                                HStack {
                                    Image(systemName: summary.passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(summary.passed ? .green : .orange)
                                    Text(summary.message)
                                        .font(.subheadline)
                                }
                                .padding()
                                .background(summary.passed ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding()
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Performance")
    }

    // MARK: - Computed

    var isRunning: Bool {
        selectedTool == .jmeter ? jmeter.isRunning : locust.isRunning
    }

    var hasResults: Bool {
        selectedTool == .jmeter ? jmeter.result != nil : locust.stats != nil
    }

    var successRate: String {
        selectedTool == .jmeter
            ? String(format: "%.1f", jmeter.result?.successRate ?? 0)
            : String(format: "%.1f", locust.stats?.successRate ?? 0)
    }

    var avgResponse: String {
        selectedTool == .jmeter
            ? String(format: "%.0f", jmeter.result?.avgResponseMs ?? 0)
            : String(format: "%.0f", locust.stats?.avgResponseMs ?? 0)
    }

    var requestsPerSec: String {
        selectedTool == .jmeter
            ? String(format: "%.1f", jmeter.result?.requestsPerSec ?? 0)
            : String(format: "%.1f", locust.stats?.requestsPerSec ?? 0)
    }

    var errorRate: String {
        selectedTool == .jmeter
            ? String(format: "%.2f", jmeter.result?.errorRate ?? 0)
            : String(format: "%.2f", locust.stats?.failureRate ?? 0)
    }

    var successColor: Color {
        let rate = Double(successRate) ?? 0
        return rate >= 95 ? .green : rate >= 80 ? .orange : .red
    }

    var resultSummary: (passed: Bool, message: String)? {
        guard hasResults else { return nil }
        let rate = Double(successRate) ?? 0
        if rate >= 95 {
            return (true, "App is stable under \(Int(userCount)) simultaneous users")
        } else {
            return (false, "App shows degradation under \(Int(userCount)) users — review error logs")
        }
    }

    // MARK: - Actions

    func runTest() async {
        if selectedTool == .jmeter {
            await jmeter.run(users: Int(userCount), duration: Int(duration))
        } else {
            await locust.run(users: Int(userCount), spawnRate: 10, duration: Int(duration))
        }
    }

    func stopTest() {
        if selectedTool == .jmeter { jmeter.stop() } else { locust.stop() }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        GroupBox {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } label: {
            Text(title).font(.subheadline)
        }
    }
}
