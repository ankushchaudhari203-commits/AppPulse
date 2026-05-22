import SwiftUI

struct OverviewView: View {
    @StateObject private var store = AppStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("App Quality Overview")
                            .font(.largeTitle).bold()
                        Text("Last updated: \(store.lastUpdated)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    EnvironmentPicker()
                }

                // Quality Score
                QualityScoreCard(score: store.qualityScore)

                // Status Cards
                HStack(spacing: 16) {
                    StatusCard(
                        title: "Functional Tests",
                        status: store.functionalStatus,
                        detail: "\(store.functionalPassed) Passed / \(store.functionalFailed) Failed",
                        icon: "checkmark.seal"
                    )
                    StatusCard(
                        title: "Performance",
                        status: store.performanceStatus,
                        detail: store.performanceSummary,
                        icon: "bolt.horizontal"
                    )
                    StatusCard(
                        title: "API Health",
                        status: store.apiHealthStatus,
                        detail: store.apiHealthSummary,
                        icon: "antenna.radiowaves.left.and.right"
                    )
                }

                // Issues
                if !store.issues.isEmpty {
                    IssuesBanner(issues: store.issues)
                }

                // Recent Runs
                RecentRunsList(runs: store.recentRuns)
            }
            .padding(24)
        }
        .navigationTitle("Overview")
    }
}

struct QualityScoreCard: View {
    let score: Int

    var color: Color {
        score >= 80 ? .green : score >= 60 ? .orange : .red
    }

    var label: String {
        score >= 80 ? "GOOD" : score >= 60 ? "NEEDS ATTENTION" : "CRITICAL"
    }

    var body: some View {
        GroupBox {
            HStack(spacing: 32) {
                VStack {
                    Text("\(score)%")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(color)
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(color)
                }
                ProgressView(value: Double(score), total: 100)
                    .progressViewStyle(.linear)
                    .tint(color)
                    .scaleEffect(x: 1, y: 3)
            }
            .padding()
        } label: {
            Text("Quality Score")
                .font(.headline)
        }
    }
}

struct StatusCard: View {
    let title: String
    let status: HealthStatus
    let detail: String
    let icon: String

    var body: some View {
        GroupBox {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(status.color)
                Circle()
                    .fill(status.color)
                    .frame(width: 12, height: 12)
                Text(detail)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } label: {
            Text(title).font(.headline)
        }
    }
}

struct IssuesBanner: View {
    let issues: [String]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues, id: \.self) { issue in
                    Label(issue, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
        } label: {
            Text("\(issues.count) issue(s) need attention")
                .font(.headline)
                .foregroundStyle(.orange)
        }
    }
}

struct RecentRunsList: View {
    let runs: [TestRun]

    var body: some View {
        GroupBox("Recent Runs") {
            VStack(spacing: 0) {
                ForEach(runs) { run in
                    HStack {
                        Image(systemName: run.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(run.passed ? .green : .red)
                        Text(run.name)
                        Spacer()
                        Text(run.tool)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(run.date)
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    Divider()
                }
            }
            .padding(4)
        }
    }
}

struct EnvironmentPicker: View {
    @StateObject private var store = AppStore.shared

    var body: some View {
        Picker("Environment", selection: $store.selectedEnvironment) {
            ForEach(store.environments, id: \.name) { env in
                Text(env.name).tag(env)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 160)
    }
}
