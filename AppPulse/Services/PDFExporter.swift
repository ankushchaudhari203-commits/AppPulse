import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Exporter

enum PDFExporter {
    @MainActor
    static func export<V: View>(title: String, @ViewBuilder content: () -> V) {
        let view = content()
            .frame(width: 500)
            .padding(36)
            .background(Color(nsColor: .windowBackgroundColor))

        // ImageRenderer uses SwiftUI's own layout engine — no NSHostingView needed
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = .init(width: 572, height: nil)

        let pdfData = NSMutableData()
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }
            ctx.beginPDFPage(nil)
            draw(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
        }

        guard !pdfData.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title                = "Save PDF"
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        panel.nameFieldStringValue = "\(title)_\(f.string(from: Date())).pdf"
        panel.allowedContentTypes  = [.pdf]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pdfData.write(to: url, atomically: true)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Printable: Single Test Run

struct PrintableTestRunView: View {
    let run: TestRun

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            printHeader(title: run.name,
                        subtitle: run.date.formatted(date: .complete, time: .shortened),
                        icon: "checklist")

            HStack(spacing: 12) {
                PrintStatCell(label: "Total",    value: "\(run.totalTests)",  color: .blue)
                PrintStatCell(label: "Passed",   value: "\(run.passedTests)", color: .green)
                PrintStatCell(label: "Failed",   value: "\(run.failedTests)", color: .red)
                PrintStatCell(label: "Pass Rate",
                              value: String(format: "%.1f%%", run.passRate),
                              color: printRateColor(run.passRate))
            }

            if !run.testCases.isEmpty {
                printDivider("Test Cases (\(run.testCases.count))")
                VStack(spacing: 0) {
                    ForEach(run.testCases) { tc in
                        HStack(spacing: 10) {
                            Image(systemName: tcIcon(tc.status))
                                .foregroundStyle(tcColor(tc.status))
                                .font(.subheadline)
                                .frame(width: 16)
                            Text(tc.name)
                                .font(.system(.subheadline, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            if tc.duration > 0 {
                                Text(tc.duration < 1
                                     ? String(format: "%.0f ms", tc.duration * 1000)
                                     : String(format: "%.2f s", tc.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            }

            if !run.notes.isEmpty {
                printDivider("Notes")
                Text(run.notes).font(.subheadline).foregroundStyle(.secondary)
            }

            printFooter()
        }
    }

    private func tcIcon(_ s: TestCase.TestCaseStatus) -> String {
        switch s { case .passed: return "checkmark.circle.fill"; case .failed: return "xmark.circle.fill"; case .skipped: return "minus.circle.fill" }
    }
    private func tcColor(_ s: TestCase.TestCaseStatus) -> Color {
        switch s { case .passed: return .green; case .failed: return .red; case .skipped: return .secondary }
    }
}

// MARK: - Printable: JMeter Run

struct PrintableJMeterRunView: View {
    let run: JMeterRun

    private var labels: [String] { Array(Set(run.samples.map(\.label))).sorted() }
    private func labelStats(_ label: String) -> (count: Int, pass: Double, avgRT: Double) {
        let s = run.samples.filter { $0.label == label }
        guard !s.isEmpty else { return (0, 0, 0) }
        let pass = Double(s.filter(\.success).count) / Double(s.count) * 100
        let avg  = s.map(\.responseTime).reduce(0, +) / Double(s.count) * 1000
        return (s.count, pass, avg)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            printHeader(title: run.name,
                        subtitle: run.importedAt.formatted(date: .complete, time: .shortened),
                        icon: "bolt.horizontal")

            HStack(spacing: 12) {
                PrintStatCell(label: "Samples",   value: "\(run.samples.count)", color: .blue)
                PrintStatCell(label: "Pass Rate",
                              value: String(format: "%.1f%%", run.passRate),
                              color: printRateColor(run.passRate))
                PrintStatCell(label: "Avg RT",
                              value: String(format: "%.0f ms", run.avgResponseTime), color: .purple)
                PrintStatCell(label: "Errors",
                              value: "\(run.samples.filter { !$0.success }.count)", color: .red)
            }

            if !labels.isEmpty {
                printDivider("Per-Label Results")
                VStack(spacing: 0) {
                    HStack {
                        Text("Label")      .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        Text("Count")      .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 55, alignment: .trailing)
                        Text("Pass Rate")  .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 75, alignment: .trailing)
                        Text("Avg RT")     .font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.08))
                    Divider()
                    ForEach(labels, id: \.self) { label in
                        let s = labelStats(label)
                        HStack {
                            Text(label).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(s.count)").font(.caption.monospacedDigit()).frame(width: 55, alignment: .trailing)
                            Text(String(format: "%.0f%%", s.pass))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(printRateColor(s.pass))
                                .frame(width: 75, alignment: .trailing)
                            Text(String(format: "%.0f ms", s.avgRT))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        Divider()
                    }
                }
            }

            if !run.notes.isEmpty {
                printDivider("Notes")
                Text(run.notes).font(.subheadline).foregroundStyle(.secondary)
            }

            printFooter()
        }
    }
}

// MARK: - Printable: Full QA Report

struct PrintableReportView: View {
    let testRuns:     [TestRun]
    let jmeterRuns:   [JMeterRun]
    let healthChecks: [HealthCheck]
    let locustStats:  LocustStats?

    private var passRate: Double {
        guard !testRuns.isEmpty else { return 0 }
        return testRuns.map(\.passRate).reduce(0, +) / Double(testRuns.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            printHeader(title: "QA Report",
                        subtitle: Date().formatted(date: .complete, time: .shortened),
                        icon: "doc.text.magnifyingglass")

            if !testRuns.isEmpty {
                printDivider("Functional Tests")
                HStack(spacing: 12) {
                    PrintStatCell(label: "Runs",      value: "\(testRuns.count)",                        color: .blue)
                    PrintStatCell(label: "Tests",     value: "\(testRuns.map(\.totalTests).reduce(0,+))", color: .purple)
                    PrintStatCell(label: "Pass Rate", value: String(format: "%.1f%%", passRate),          color: printRateColor(passRate))
                }
                VStack(spacing: 0) {
                    ForEach(testRuns) { run in
                        HStack {
                            Circle().fill(printRateColor(run.passRate)).frame(width: 7, height: 7)
                            Text(run.name).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(run.date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", run.passRate))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(printRateColor(run.passRate).opacity(0.12))
                                .foregroundStyle(printRateColor(run.passRate))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            }

            if !jmeterRuns.isEmpty {
                printDivider("JMeter Load Tests")
                let avgPass = jmeterRuns.map(\.passRate).reduce(0,+) / Double(jmeterRuns.count)
                HStack(spacing: 12) {
                    PrintStatCell(label: "Runs",     value: "\(jmeterRuns.count)",                             color: .orange)
                    PrintStatCell(label: "Samples",  value: "\(jmeterRuns.map { $0.samples.count }.reduce(0,+))", color: .blue)
                    PrintStatCell(label: "Avg Pass", value: String(format: "%.1f%%", avgPass),                 color: printRateColor(avgPass))
                }
                VStack(spacing: 0) {
                    ForEach(jmeterRuns) { run in
                        HStack {
                            Circle().fill(printRateColor(run.passRate)).frame(width: 7, height: 7)
                            Text(run.name).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(run.importedAt.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", run.passRate))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(printRateColor(run.passRate).opacity(0.12))
                                .foregroundStyle(printRateColor(run.passRate))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            }

            if !healthChecks.isEmpty {
                printDivider("API Health")
                let healthy = healthChecks.filter { $0.status == .healthy }.count
                HStack(spacing: 12) {
                    PrintStatCell(label: "Monitored", value: "\(healthChecks.count)", color: .teal)
                    PrintStatCell(label: "Healthy",   value: "\(healthy)",             color: .green)
                    PrintStatCell(label: "Down",      value: "\(healthChecks.filter { $0.status == .down }.count)", color: .red)
                }
                VStack(spacing: 0) {
                    ForEach(healthChecks) { check in
                        HStack {
                            Image(systemName: check.status == .healthy ? "checkmark.circle.fill" : check.status == .down ? "xmark.circle.fill" : "exclamationmark.circle.fill")
                                .foregroundStyle(check.status == .healthy ? .green : check.status == .down ? .red : .orange)
                                .font(.subheadline)
                            Text(check.endpoint).font(.subheadline).lineLimit(1)
                            Spacer()
                            if check.responseTime > 0 {
                                Text("\(Int(check.responseTime * 1000)) ms").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 5)
                        Divider()
                    }
                }
            }

            if let s = locustStats {
                printDivider("Locust Load Test")
                HStack(spacing: 12) {
                    PrintStatCell(label: "RPS",        value: String(format: "%.1f", s.currentRPS),        color: .blue)
                    PrintStatCell(label: "Users",      value: "\(s.userCount)",                            color: .purple)
                    PrintStatCell(label: "Fail Ratio", value: String(format: "%.1f%%", s.failRatio * 100), color: s.failRatio > 0.05 ? .red : .green)
                    PrintStatCell(label: "State",      value: s.state.capitalized,                        color: .orange)
                }
            }

            printFooter()
        }
    }
}

// MARK: - Shared helpers (file-level, used by all printable views)

func printHeader(title: String, subtitle: String, icon: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.blue)
            Text(title)
                .font(.title2.weight(.bold))
        }
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Divider().padding(.top, 4)
    }
}

func printDivider(_ label: String) -> some View {
    HStack(spacing: 6) {
        Text(label.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        Rectangle().frame(height: 1).foregroundStyle(Color.secondary.opacity(0.2))
    }
}

func printFooter() -> some View {
    Text("Generated by AppPulse · \(Date().formatted(date: .abbreviated, time: .shortened))")
        .font(.caption2)
        .foregroundStyle(Color.secondary.opacity(0.6))
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
}

func printRateColor(_ rate: Double) -> Color {
    rate >= 90 ? .green : rate >= 70 ? .orange : .red
}

struct PrintStatCell: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
