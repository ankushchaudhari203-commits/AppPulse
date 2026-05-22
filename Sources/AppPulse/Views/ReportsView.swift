import SwiftUI

struct ReportsView: View {
    @StateObject private var store = AppStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Reports")
                            .font(.largeTitle).bold()
                        Text("Share quality status with your team")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        store.generateReport()
                    } label: {
                        Label("Generate Report", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                ForEach(store.reports) { report in
                    ReportRow(report: report)
                }

                if store.reports.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No reports yet",
                        message: "Run tests and generate a report to share with your team"
                    )
                }
            }
            .padding(24)
        }
        .navigationTitle("Reports")
    }
}

struct ReportRow: View {
    let report: Report

    var body: some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.title).font(.headline)
                    Text(report.date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Label("\(report.passRate)% pass rate", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                            .font(.caption)
                        if report.openIssues > 0 {
                            Label("\(report.openIssues) open issues", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                        }
                    }
                }
                Spacer()
                Button {
                    report.exportPDF()
                } label: {
                    Label("Export PDF", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    report.exportCSV()
                } label: {
                    Label("Export CSV", systemImage: "tablecells")
                }
                .buttonStyle(.bordered)
            }
            .padding(8)
        }
    }
}
