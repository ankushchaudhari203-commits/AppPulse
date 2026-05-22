import SwiftUI
import Charts

struct OverviewView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Stat cards ─────────────────────────────────────────
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 16
                    ) {
                        StatCard(
                            title: "Total Runs",
                            value: "\(store.testRuns.count)",
                            subtitle: store.testRuns.first.map { "Last: \($0.name)" } ?? "No runs yet",
                            icon: "testtube.2", color: .blue,
                            sparkline: passRateSparkline
                        )
                        StatCard(
                            title: "Pass Rate",
                            value: store.testRuns.isEmpty ? "—" : String(format: "%.0f%%", store.passRate),
                            subtitle: "\(store.testRuns.filter { $0.status == .passed }.count) passed",
                            icon: "checkmark.seal.fill", color: passRateColor,
                            sparkline: passRateSparkline
                        )
                        StatCard(
                            title: "API Health",
                            value: store.healthChecks.isEmpty ? "—" : store.healthySummary,
                            subtitle: store.healthChecks.isEmpty ? "No endpoints added" : "endpoints healthy",
                            icon: "network", color: apiHealthColor,
                            sparkline: healthSparkline
                        )
                        StatCard(
                            title: "Load Test",
                            value: loadTestValue,
                            subtitle: loadTestSubtitle,
                            icon: "gauge.high", color: loadTestColor,
                            sparkline: loadTestSparkline
                        )
                    }

                    // ── Recent Activity ────────────────────────────────────
                    if hasActivity {
                        RecentActivitySection()
                    } else {
                        GettingStartedCard()
                    }

                    // ── Trends ─────────────────────────────────────────────
                    if hasTrendsData {
                        TrendsSection()
                    }
                }
                .padding()

                if let updated = store.lastUpdated {
                    HStack {
                        Text("Last refreshed \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("AppPulse")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        if store.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(store.isRefreshing)
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
            .task { await store.refresh() }
        }
    }

    private var hasActivity: Bool {
        !store.testRuns.isEmpty || !store.jmeterRuns.isEmpty ||
        !store.locustRuns.isEmpty || store.lastUpdated != nil
    }

    private var hasTrendsData: Bool {
        store.testRuns.count >= 3 || store.jmeterRuns.count >= 3
    }

    // MARK: - Colors

    private var passRateColor: Color {
        guard !store.testRuns.isEmpty else { return .secondary }
        switch store.passRate {
        case 90...: return .green
        case 70..<90: return .orange
        default: return .red
        }
    }

    private var apiHealthColor: Color {
        guard !store.healthChecks.isEmpty else { return .secondary }
        let ratio = Double(store.healthChecks.filter { $0.status == .healthy }.count) / Double(store.healthChecks.count)
        switch ratio {
        case 1.0: return .green
        case 0.5...: return .orange
        default: return .red
        }
    }

    private var loadTestColor: Color {
        if store.locustIsRunning { return .orange }
        if !store.jmeterSamples.isEmpty {
            let rate = Double(store.jmeterSamples.filter(\.success).count) / Double(store.jmeterSamples.count) * 100
            if rate >= 95 { return .green }
            if rate >= 80 { return .orange }
            return .red
        }
        return .secondary
    }

    // MARK: - Sparklines

    private var passRateSparkline: [Double] {
        store.testRuns.prefix(10).reversed().map(\.passRate)
    }

    private var healthSparkline: [Double] {
        let histories = Array(store.healthHistory.values)
        guard !histories.isEmpty else { return [] }
        let minCount = histories.map(\.count).min() ?? 0
        guard minCount > 0 else { return [] }
        let last = min(20, minCount)
        return ((minCount - last)..<minCount).map { i in
            let healthy = histories.filter { $0[i].status == .healthy }.count
            return Double(healthy) / Double(histories.count) * 100
        }
    }

    private var loadTestSparkline: [Double] {
        if !store.jmeterRuns.isEmpty {
            return store.jmeterRuns.prefix(10).reversed().map(\.passRate)
        }
        if !store.locustRuns.isEmpty {
            return store.locustRuns.prefix(10).reversed().map { (1 - $0.avgFailRatio) * 100 }
        }
        return []
    }

    // MARK: - Load test display

    private var loadTestValue: String {
        if store.locustIsRunning || store.locustStats != nil {
            return store.locustStats?.state.capitalized ?? "Connecting"
        }
        if !store.jmeterSamples.isEmpty {
            let pass = store.jmeterSamples.filter(\.success).count
            return String(format: "%.0f%%", Double(pass) / Double(store.jmeterSamples.count) * 100)
        }
        return "Idle"
    }

    private var loadTestSubtitle: String {
        if store.locustIsRunning || store.locustStats != nil {
            return store.locustStats.map { String(format: "%.1f RPS", $0.currentRPS) } ?? "localhost:8089"
        }
        if !store.jmeterSamples.isEmpty {
            let avgRT = store.jmeterSamples.map(\.responseTime).reduce(0, +) / Double(store.jmeterSamples.count) * 1000
            return String(format: "%d samples • %.0f ms avg", store.jmeterSamples.count, avgRT)
        }
        return "No data yet"
    }
}

// MARK: - Recent Activity

private struct RecentActivitySection: View {
    @EnvironmentObject var store: AppStore

    private struct ActivityItem: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
        let date: Date
    }

    private var items: [ActivityItem] {
        var result: [ActivityItem] = []

        for run in store.testRuns.prefix(3) {
            let color: Color = run.passRate >= 90 ? .green : run.passRate >= 70 ? .orange : .red
            result.append(ActivityItem(
                icon: "checklist",
                color: color,
                title: run.name,
                detail: String(format: "%.0f%% pass · %d/%d tests", run.passRate, run.passedTests, run.totalTests),
                date: run.date
            ))
        }

        for run in store.jmeterRuns.prefix(2) {
            let color: Color = run.passRate >= 95 ? .green : run.passRate >= 80 ? .orange : .red
            result.append(ActivityItem(
                icon: "bolt.horizontal",
                color: color,
                title: run.name,
                detail: String(format: "%.0f%% pass · %d samples · %.0f ms avg", run.passRate, run.samples.count, run.avgResponseTime),
                date: run.importedAt
            ))
        }

        for run in store.locustRuns.prefix(2) {
            let passRate = (1 - run.avgFailRatio) * 100
            let color: Color = passRate >= 95 ? .green : passRate >= 80 ? .orange : .red
            result.append(ActivityItem(
                icon: "hare",
                color: color,
                title: run.name,
                detail: String(format: "%.0f%% pass · %d users · %.1f RPS peak", passRate, run.userCount, run.peakRPS),
                date: run.date
            ))
        }

        if let lastUpdated = store.lastUpdated, !store.healthChecks.isEmpty {
            let healthy = store.healthChecks.filter { $0.status == .healthy }.count
            let total = store.healthChecks.count
            let color: Color = healthy == total ? .green : healthy > 0 ? .orange : .red
            result.append(ActivityItem(
                icon: "network",
                color: color,
                title: "API Health Check",
                detail: "\(healthy)/\(total) endpoints healthy",
                date: lastUpdated
            ))
        }

        return result.sorted { $0.date > $1.date }.prefix(6).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Activity")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.subheadline)
                            .foregroundStyle(item.color)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(item.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(item.date.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)

                    if idx < items.count - 1 {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - Getting Started (shown when app has no data)

private struct GettingStartedCard: View {
    private let steps: [(icon: String, color: Color, title: String, detail: String)] = [
        ("testtube.2",      .blue,   "Import test results",    "Drag & drop an .xcresult from Xcode into Functional Tests"),
        ("bolt.horizontal", .orange, "Run a load test",        "Go to Performance → JMeter and import a .jtl results file"),
        ("network",         .teal,   "Monitor API endpoints",  "Add any URL in API Health to track uptime and response time"),
        ("sparkles",        .purple, "Generate test cases",    "Use AI Tests to generate test cases from a user story"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Get Started")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    HStack(spacing: 12) {
                        Image(systemName: step.icon)
                            .font(.subheadline)
                            .foregroundStyle(step.color)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                                .font(.subheadline.weight(.medium))
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    if idx < steps.count - 1 {
                        Divider().padding(.leading, 46)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        }
    }
}

#Preview {
    OverviewView()
        .environmentObject(AppStore())
}

// MARK: - Trends

private struct TrendsSection: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trends")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(spacing: 12) {
                if store.testRuns.count >= 3 {
                    TrendChart(
                        title: "Functional Tests Pass Rate",
                        icon: "checklist",
                        color: .blue,
                        points: store.testRuns.reversed().suffix(20).map {
                            TrendPoint(date: $0.date, value: $0.passRate)
                        }
                    )
                }
                if store.jmeterRuns.count >= 3 {
                    TrendChart(
                        title: "JMeter Pass Rate",
                        icon: "bolt.horizontal",
                        color: .orange,
                        points: store.jmeterRuns.reversed().suffix(20).map {
                            TrendPoint(date: $0.importedAt, value: $0.passRate)
                        }
                    )
                }
            }
        }
    }
}

private struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

private struct TrendChart: View {
    let title: String
    let icon: String
    let color: Color
    let points: [TrendPoint]

    private var avg: Double {
        points.isEmpty ? 0 : points.map(\.value).reduce(0, +) / Double(points.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text("Avg \(Int(avg))%")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }

            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Pass Rate", point.value)
                )
                .foregroundStyle(color)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Pass Rate", point.value)
                )
                .foregroundStyle(color.opacity(0.08))
                .interpolationMethod(.catmullRom)

                RuleMark(y: .value("Threshold", 95))
                    .foregroundStyle(.green.opacity(0.4))
                    .lineStyle(StrokeStyle(dash: [4]))
                    .annotation(position: .trailing) {
                        Text("95%").font(.system(size: 9)).foregroundStyle(.green.opacity(0.6))
                    }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 95, 100]) { val in
                    AxisGridLine()
                    AxisValueLabel { Text("\(val.as(Int.self) ?? 0)%").font(.caption2) }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 110)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}
