import SwiftUI
import AppKit
import Charts
import UniformTypeIdentifiers

struct ReportsView: View {
    @EnvironmentObject var store: AppStore
    @State private var copied = false
    @State private var exported = false
    
    private var hasData: Bool {
        !store.testRuns.isEmpty || !store.healthChecks.isEmpty || store.locustStats != nil || !store.jmeterRuns.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if hasData {
                    reportBody
                } else {
                    emptyState
                }
            }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        let runs    = store.testRuns
                        let jmeter  = store.jmeterRuns
                        let health  = store.healthChecks
                        let locust  = store.locustStats
                        PDFExporter.export(title: "QA Report") {
                            PrintableReportView(
                                testRuns:     runs,
                                jmeterRuns:   jmeter,
                                healthChecks: health,
                                locustStats:  locust
                            )
                        }
                    } label: {
                        Label("Print / PDF", systemImage: "printer")
                    }
                    .disabled(!hasData)
                    .keyboardShortcut("p", modifiers: .command)
                    .help("Print report or save as PDF")
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        exportReport()
                        exported = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exported = false }
                    } label: {
                        Label(
                            exported ? "Exported!" : "Export HTML",
                            systemImage: exported ? "checkmark.circle.fill" : "arrow.down.doc"
                        )
                    }
                    .disabled(!hasData)
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        copyReport()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                    } label: {
                        Label(
                            copied ? "Copied!" : "Copy Report",
                            systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                    }
                    .disabled(!hasData)
                }
            }
        }
    }
    
    private var reportBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("QA Report")
                        .font(.title2.weight(.bold))
                    Text(Date().formatted(date: .complete, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                ReportSection(title: "Functional Tests", icon: "testtube.2", color: .blue) {
                    FunctionalTestsSection()
                }

                if store.testRuns.count >= 2 {
                    ReportSection(title: "Run Comparison", icon: "arrow.left.arrow.right", color: .indigo) {
                        RunComparisonSection()
                    }
                }

                if store.jmeterRuns.count >= 2 {
                    ReportSection(title: "JMeter Trend", icon: "bolt.horizontal", color: .orange) {
                        JMeterTrendSection()
                    }
                    ReportSection(title: "JMeter Run Comparison", icon: "arrow.left.arrow.right", color: .orange) {
                        JMeterComparisonSection()
                    }
                }
                
                ReportSection(title: "API Health", icon: "network", color: .teal) {
                    APIHealthSection()
                }
                
                ReportSection(title: "Load Test", icon: "gauge.high", color: .orange) {
                    LoadTestSection()
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Nothing to report yet")
                .font(.headline)
            Text("Import test results, add API endpoints, or connect Locust to generate a report")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func copyReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(buildReportText(), forType: .string)
    }
    
    private func exportReport() {
        let panel = NSSavePanel()
        panel.title = "Export QA Report"
        panel.nameFieldStringValue = "AppPulse_Report_\(formattedDateForFilename()).html"
        panel.allowedContentTypes = [UTType.html]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? buildHTMLReport().write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }
    
    private func formattedDateForFilename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm"
        return f.string(from: Date())
    }
    
    private func buildReportText() -> String {
        var lines: [String] = []
        lines += [
            "AppPulse QA Report — \(Date().formatted(date: .complete, time: .shortened))",
            String(repeating: "=", count: 60),
            ""
        ]
        
        lines += ["FUNCTIONAL TESTS", String(repeating: "-", count: 40)]
        if store.testRuns.isEmpty {
            lines.append("No test runs.")
        } else {
            let total = store.testRuns.map(\.totalTests).reduce(0, +)
            lines.append("Runs: \(store.testRuns.count)  |  Tests: \(total)  |  Pass Rate: \(String(format: "%.1f%%", store.passRate))")
            for run in store.testRuns {
                lines.append("  • \(run.name): \(String(format: "%.0f%%", run.passRate)) (\(run.passedTests)/\(run.totalTests)) — \(run.date.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        lines.append("")
        
        lines += ["API HEALTH", String(repeating: "-", count: 40)]
        if store.healthChecks.isEmpty {
            lines.append("No endpoints monitored.")
        } else {
            let healthy = store.healthChecks.filter { $0.status == .healthy }.count
            lines.append("Healthy: \(healthy)/\(store.healthChecks.count)")
            for check in store.healthChecks {
                let mark = check.status == .healthy ? "✓" : "✗"
                let code = check.statusCode.map { " HTTP \($0)" } ?? ""
                let rt   = check.responseTime > 0 ? " \(Int(check.responseTime * 1000))ms" : ""
                lines.append("  \(mark) \(check.endpoint)\(code)\(rt) [\(check.status.rawValue.uppercased())]")
            }
        }
        lines.append("")
        
        lines += ["LOAD TEST", String(repeating: "-", count: 40)]
        if !store.jmeterRuns.isEmpty {
            let totalSamples = store.jmeterRuns.map { $0.samples.count }.reduce(0, +)
            let avgPass = store.jmeterRuns.map(\.passRate).reduce(0, +) / Double(store.jmeterRuns.count)
            lines.append("JMeter — Runs: \(store.jmeterRuns.count)  |  Samples: \(totalSamples)  |  Avg Pass: \(String(format: "%.1f%%", avgPass))")
            for run in store.jmeterRuns {
                lines.append("  • \(run.name): \(String(format: "%.0f%%", run.passRate)) (\(run.samples.count) samples) — \(run.importedAt.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        if let s = store.locustStats {
            if !store.jmeterRuns.isEmpty { lines.append("") }
            lines.append("Locust — State: \(s.state.capitalized)  |  RPS: \(String(format: "%.1f", s.currentRPS))  |  Users: \(s.userCount)  |  Fail Ratio: \(String(format: "%.1f%%", s.failRatio * 100))")
        }
        if store.jmeterRuns.isEmpty && store.locustStats == nil {
            lines.append("No load test data.")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - HTML Report
    
    private func buildHTMLReport() -> String {
        let date = Date().formatted(date: .complete, time: .shortened)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="UTF-8">
        <title>AppPulse QA Report</title>
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f2f2f7; color: #1c1c1e; padding: 32px; }
          .container { max-width: 860px; margin: 0 auto; }
          .card { background: white; border-radius: 16px; padding: 24px 28px; margin-bottom: 18px; box-shadow: 0 2px 10px rgba(0,0,0,0.07); }
          .header-logo { font-size: 36px; margin-right: 14px; }
          .header h1 { font-size: 26px; font-weight: 700; }
          .header .date { font-size: 13px; color: #8e8e93; margin-top: 4px; }
          .section-title { font-size: 16px; font-weight: 600; margin-bottom: 16px; display: flex; align-items: center; gap: 8px; }
          .pills { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 14px; }
          .pill { padding: 8px 14px; border-radius: 10px; text-align: center; min-width: 72px; }
          .pill .val { font-size: 20px; font-weight: 700; }
          .pill .lbl { font-size: 11px; color: #6e6e73; margin-top: 2px; }
          .divider { height: 1px; background: #f2f2f7; margin: 12px 0; }
          .row { display: flex; align-items: center; justify-content: space-between; padding: 9px 0; border-bottom: 1px solid #f2f2f7; }
          .row:last-child { border-bottom: none; }
          .row-left { display: flex; align-items: center; gap: 10px; }
          .dot { width: 9px; height: 9px; border-radius: 50%; flex-shrink: 0; }
          .run-name { font-size: 14px; font-weight: 500; }
          .run-meta { font-size: 12px; color: #8e8e93; margin-top: 2px; }
          .badge { padding: 3px 9px; border-radius: 6px; font-size: 12px; font-weight: 600; }
          .status-badge { display: inline-flex; align-items: center; gap: 5px; padding: 4px 10px; border-radius: 7px; font-size: 12px; font-weight: 600; }
          .endpoint-name { font-size: 14px; font-weight: 500; }
          .endpoint-url { font-size: 11px; color: #8e8e93; }
          .code { font-family: monospace; font-size: 12px; padding: 3px 8px; border-radius: 5px; font-weight: 500; }
          .rt { font-size: 12px; }
          .no-data { color: #8e8e93; font-size: 14px; padding: 6px 0; }
          .subtitle { font-size: 11px; font-weight: 600; color: #8e8e93; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 10px; }
          .green  { color: #1a7f37; background: #eafaf1; }
          .orange { color: #b45309; background: #fff7ed; }
          .red    { color: #c0392b; background: #fef2f2; }
          .blue   { color: #0057b8; background: #eff6ff; }
          .purple { color: #7c3aed; background: #faf5ff; }
          .teal   { color: #0e7490; background: #f0fdfa; }
          .gray   { color: #6e6e73; background: #f2f2f7; }
          .footer { text-align: center; color: #8e8e93; font-size: 12px; margin-top: 8px; }
        </style>
        </head>
        <body>
        <div class="container">
        
        <div class="card" style="display:flex;align-items:center;">
          <span class="header-logo">📊</span>
          <div class="header">
            <h1>AppPulse QA Report</h1>
            <div class="date">\(date)</div>
          </div>
        </div>
        
        \(htmlFunctionalSection())
        \(htmlAPIHealthSection())
        \(htmlLoadTestSection())
        
        <div class="footer">Generated by AppPulse</div>
        </div>
        </body>
        </html>
        """
    }
    
    private func htmlFunctionalSection() -> String {
        var html = "<div class=\"card\"><div class=\"section-title\">🧪 Functional Tests</div>"
        if store.testRuns.isEmpty {
            html += "<p class=\"no-data\">No test runs imported.</p>"
        } else {
            let total = store.testRuns.map(\.totalTests).reduce(0, +)
            let passColor = store.passRate >= 90 ? "green" : store.passRate >= 70 ? "orange" : "red"
            html += """
            <div class="pills">
              <div class="pill blue"><div class="val">\(store.testRuns.count)</div><div class="lbl">Runs</div></div>
              <div class="pill purple"><div class="val">\(total)</div><div class="lbl">Total Tests</div></div>
              <div class="pill \(passColor)"><div class="val">\(String(format: "%.0f%%", store.passRate))</div><div class="lbl">Pass Rate</div></div>
            </div>
            <div class="divider"></div>
            """
            for run in store.testRuns {
                let c = run.passRate >= 90 ? "green" : run.passRate >= 70 ? "orange" : "red"
                html += """
                <div class="row">
                  <div class="row-left">
                    <span class="dot" style="background:\(dotColor(c))"></span>
                    <div><div class="run-name">\(run.name)</div>
                    <div class="run-meta">\(run.date.formatted(date: .abbreviated, time: .omitted)) · \(run.passedTests)/\(run.totalTests) passed</div></div>
                  </div>
                  <span class="badge \(c)">\(String(format: "%.0f%%", run.passRate))</span>
                </div>
                """
            }
        }
        return html + "</div>"
    }
    
    private func htmlAPIHealthSection() -> String {
        var html = "<div class=\"card\"><div class=\"section-title\">🌐 API Health</div>"
        if store.healthChecks.isEmpty {
            html += "<p class=\"no-data\">No endpoints monitored.</p>"
        } else {
            let healthy = store.healthChecks.filter { $0.status == .healthy }.count
            let down    = store.healthChecks.filter { $0.status == .down    }.count
            let overall = down > 0 ? "red" : healthy == store.healthChecks.count ? "green" : "orange"
            html += """
            <div class="pills">
              <div class="pill \(overall)"><div class="val">\(healthy)/\(store.healthChecks.count)</div><div class="lbl">Healthy</div></div>
              \(down > 0 ? "<div class=\"pill red\"><div class=\"val\">\(down)</div><div class=\"lbl\">Down</div></div>" : "")
            </div>
            <div class="divider"></div>
            """
            for check in store.healthChecks {
                let sc = statusClass(check.status)
                let label = statusText(check.status)
                let domain = URL(string: check.endpoint)?.host ?? check.endpoint
                let codeStr = check.statusCode.map { httpLabel($0) } ?? ""
                let rtStr = check.responseTime > 0 ? String(format: "%.0f ms · %@", check.responseTime * 1000, rtQuality(check.responseTime)) : ""
                html += """
                <div class="row">
                  <div class="row-left">
                    <span class="status-badge \(sc)"><span class="dot" style="background:\(dotColor(sc))"></span>\(label)</span>
                    <div><div class="endpoint-name">\(domain)</div>
                    <div class="endpoint-url">\(check.endpoint)</div></div>
                  </div>
                  <div style="text-align:right">
                    \(codeStr.isEmpty ? "" : "<span class=\"code \(sc)\">\(codeStr)</span>")
                    \(rtStr.isEmpty ? "" : "<div class=\"rt gray\" style=\"margin-top:3px;color:#6e6e73;\">\(rtStr)</div>")
                  </div>
                </div>
                """
            }
        }
        return html + "</div>"
    }
    
    private func htmlLoadTestSection() -> String {
        var html = "<div class=\"card\"><div class=\"section-title\">⚡ Load Test</div>"
        var hasContent = false
        
        if !store.jmeterRuns.isEmpty {
            hasContent = true
            let totalSamples = store.jmeterRuns.map { $0.samples.count }.reduce(0, +)
            let avgPass = store.jmeterRuns.map(\.passRate).reduce(0, +) / Double(store.jmeterRuns.count)
            let passColor = avgPass >= 95 ? "green" : avgPass >= 80 ? "orange" : "red"
            html += """
            <div class="subtitle">JMeter</div>
            <div class="pills">
              <div class="pill orange"><div class="val">\(store.jmeterRuns.count)</div><div class="lbl">Runs</div></div>
              <div class="pill blue"><div class="val">\(totalSamples)</div><div class="lbl">Samples</div></div>
              <div class="pill \(passColor)"><div class="val">\(String(format: "%.0f%%", avgPass))</div><div class="lbl">Avg Pass</div></div>
            </div>
            <div class="divider"></div>
            """
            for run in store.jmeterRuns {
                let c = run.passRate >= 95 ? "green" : run.passRate >= 80 ? "orange" : "red"
                let avgRT = run.avgResponseTime
                html += """
                <div class="row">
                  <div class="row-left">
                    <span class="dot" style="background:\(dotColor(c))"></span>
                    <div><div class="run-name">\(run.name)</div>
                    <div class="run-meta">\(run.importedAt.formatted(date: .abbreviated, time: .omitted)) · \(run.samples.count) samples · \(String(format: "%.0f ms avg RT", avgRT))</div></div>
                  </div>
                  <span class="badge \(c)">\(String(format: "%.0f%%", run.passRate))</span>
                </div>
                """
            }
        }
        
        if let s = store.locustStats {
            hasContent = true
            if !store.jmeterRuns.isEmpty { html += "<div class=\"divider\" style=\"margin:16px 0\"></div>" }
            let failColor = s.failRatio > 0.05 ? "red" : "green"
            html += """
            <div class="subtitle">Locust</div>
            <div class="pills">
              <div class="pill blue"><div class="val">\(String(format: "%.1f", s.currentRPS))</div><div class="lbl">RPS</div></div>
              <div class="pill purple"><div class="val">\(s.userCount)</div><div class="lbl">Users</div></div>
              <div class="pill \(failColor)"><div class="val">\(String(format: "%.1f%%", s.failRatio * 100))</div><div class="lbl">Fail Ratio</div></div>
              <div class="pill orange"><div class="val">\(s.state.capitalized)</div><div class="lbl">State</div></div>
            </div>
            """
        }
        
        if !hasContent { html += "<p class=\"no-data\">No load test data.</p>" }
        return html + "</div>"
    }
    
    private func dotColor(_ cls: String) -> String {
        switch cls {
        case "green":  return "#1a7f37"
        case "orange": return "#b45309"
        case "red":    return "#c0392b"
        case "blue":   return "#0057b8"
        default:       return "#8e8e93"
        }
    }
    
    private func statusClass(_ s: HealthCheck.HealthStatus) -> String {
        switch s { case .healthy: return "green"; case .degraded: return "orange"; case .down: return "red"; case .unknown: return "gray" }
    }
    
    private func statusText(_ s: HealthCheck.HealthStatus) -> String {
        switch s { case .healthy: return "Healthy"; case .degraded: return "Degraded"; case .down: return "Down"; case .unknown: return "Unknown" }
    }
    
    private func httpLabel(_ code: Int) -> String {
        let m: [Int:String] = [200:"200 OK",201:"201 Created",204:"204 No Content",301:"301 Moved",302:"302 Found",400:"400 Bad Request",401:"401 Unauthorized",403:"403 Forbidden",404:"404 Not Found",500:"500 Server Error",502:"502 Bad Gateway",503:"503 Unavailable",504:"504 Timeout"]
        return m[code] ?? "\(code)"
    }
    
    private func rtQuality(_ rt: TimeInterval) -> String {
        let ms = rt * 1000
        if ms < 200 { return "Fast" }
        if ms < 1000 { return "Acceptable" }
        return "Slow"
    }
    
    // MARK: - Section Container
    
    struct ReportSection<Content: View>: View {
        let title: String
        let icon: String
        let color: Color
        @ViewBuilder var content: Content
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.subheadline.weight(.semibold))
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
        }
    }
    
    // MARK: - Functional Tests
    
    struct FunctionalTestsSection: View {
        @EnvironmentObject var store: AppStore

        private var totalTests: Int { store.testRuns.map(\.totalTests).reduce(0, +) }
        private var sortedRuns: [TestRun] { store.testRuns.sorted { $0.date < $1.date } }

        var body: some View {
            if store.testRuns.isEmpty {
                Text("No test runs imported")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 20) {
                        PassRateRing(rate: store.passRate, size: 88)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                ReportStatPill(value: "\(store.testRuns.count)", label: "runs",  color: .blue)
                                ReportStatPill(value: "\(totalTests)",           label: "tests", color: .purple)
                            }
                            Divider()
                            ForEach(store.testRuns) { run in
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(rateColor(run.passRate))
                                        .frame(width: 7, height: 7)
                                    Text(run.name)
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(run.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(String(format: "%.0f%%", run.passRate))
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(rateColor(run.passRate).opacity(0.12))
                                        .foregroundStyle(rateColor(run.passRate))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if sortedRuns.count >= 2 {
                        Divider()
                        PassRateTrendChart(runs: sortedRuns)
                    }
                }
            }
        }
    }
    
    struct PassRateRing: View {
        let rate: Double
        let size: CGFloat
        
        private var color: Color { rateColor(rate) }
        
        var body: some View {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: rate / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: rate)
                VStack(spacing: 1) {
                    Text(String(format: "%.0f%%", rate))
                        .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("Pass")
                        .font(.system(size: size * 0.13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)
        }
    }
    
    // MARK: - API Health
    
    struct APIHealthSection: View {
        @EnvironmentObject var store: AppStore
        
        private var healthyCount: Int { store.healthChecks.filter { $0.status == .healthy }.count }
        private var downCount:    Int { store.healthChecks.filter { $0.status == .down    }.count }
        private var ratio: Double {
            store.healthChecks.isEmpty ? 0 : Double(healthyCount) / Double(store.healthChecks.count)
        }
        
        var body: some View {
            if store.healthChecks.isEmpty {
                Text("No endpoints monitored")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    ReportStatPill(
                        value: "\(healthyCount)/\(store.healthChecks.count)",
                        label: "healthy",
                        color: ratio == 1 ? .green : ratio >= 0.5 ? .orange : .red
                    )
                    if downCount > 0 {
                        ReportStatPill(value: "\(downCount)", label: "down", color: .red)
                    }
                }
                Divider()
                ForEach(store.healthChecks) { check in
                    HStack(spacing: 10) {
                        Image(systemName: statusIcon(check.status))
                            .foregroundStyle(statusColor(check.status))
                            .font(.subheadline)
                        Text(check.endpoint)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        if let code = check.statusCode {
                            Text("HTTP \(code)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if check.responseTime > 0 {
                            Text("\(Int(check.responseTime * 1000))ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .trailing)
                        }
                    }
                }
            }
        }
        
        private func statusIcon(_ s: HealthCheck.HealthStatus) -> String {
            switch s {
            case .healthy:  return "checkmark.circle.fill"
            case .degraded: return "exclamationmark.circle.fill"
            case .down:     return "xmark.circle.fill"
            case .unknown:  return "circle.dotted"
            }
        }
        
        private func statusColor(_ s: HealthCheck.HealthStatus) -> Color {
            switch s {
            case .healthy:  return .green
            case .degraded: return .orange
            case .down:     return .red
            case .unknown:  return .secondary
            }
        }
    }
    
    // MARK: - Load Test
    
    struct LoadTestSection: View {
        @EnvironmentObject var store: AppStore
        
        private var totalSamples: Int  { store.jmeterRuns.map { $0.samples.count }.reduce(0, +) }
        private var avgPassRate: Double {
            guard !store.jmeterRuns.isEmpty else { return 0 }
            return store.jmeterRuns.map(\.passRate).reduce(0, +) / Double(store.jmeterRuns.count)
        }
        
        var body: some View {
            if store.jmeterRuns.isEmpty && store.locustStats == nil {
                Text("No load test data — import a .jtl or connect Locust in the Performance tab")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    if !store.jmeterRuns.isEmpty {
                        Text("JMeter")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ReportStatPill(value: "\(store.jmeterRuns.count)",              label: "runs",     color: .orange)
                            ReportStatPill(value: "\(totalSamples)",                         label: "samples",  color: .blue)
                            ReportStatPill(value: String(format: "%.1f%%", avgPassRate),     label: "avg pass", color: rateColor(avgPassRate))
                        }
                        Divider()
                        ForEach(store.jmeterRuns) { run in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(rateColor(run.passRate))
                                    .frame(width: 7, height: 7)
                                Text(run.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                Spacer()
                                Text(run.importedAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(String(format: "%.0f%%", run.passRate))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(rateColor(run.passRate).opacity(0.12))
                                    .foregroundStyle(rateColor(run.passRate))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                    
                    if let stats = store.locustStats {
                        if !store.jmeterRuns.isEmpty { Divider() }
                        Text("Locust")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ReportStatPill(value: String(format: "%.1f", stats.currentRPS),        label: "RPS",        color: .blue)
                            ReportStatPill(value: "\(stats.userCount)",                             label: "users",      color: .purple)
                            ReportStatPill(value: String(format: "%.1f%%", stats.failRatio * 100), label: "fail ratio", color: stats.failRatio > 0.05 ? .red : .green)
                            ReportStatPill(value: stats.state.capitalized,                         label: "state",      color: .orange)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Shared stat pill
    
    struct ReportStatPill: View {
        let value: String
        let label: String
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
}

private func rateColor(_ rate: Double) -> Color {
    switch rate {
    case 90...: return .green
    case 70..<90: return .orange
    default: return .red
    }
}

// MARK: - Run Comparison

    struct RunComparisonSection: View {
        @EnvironmentObject var store: AppStore
        @State private var baselineID: TestRun.ID?
        @State private var compareID: TestRun.ID?
        @State private var showPassing = false

        private var baseline: TestRun? { store.testRuns.first { $0.id == baselineID } }
        private var compare:  TestRun? { store.testRuns.first { $0.id == compareID  } }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Run pickers
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Baseline").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Baseline", selection: $baselineID) {
                            Text("Select run…").tag(nil as TestRun.ID?)
                            ForEach(store.testRuns) { run in
                                Text(run.name).tag(run.id as TestRun.ID?)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                        .padding(.top, 18)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Compare").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Picker("Compare", selection: $compareID) {
                            Text("Select run…").tag(nil as TestRun.ID?)
                            ForEach(store.testRuns) { run in
                                Text(run.name).tag(run.id as TestRun.ID?)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let baseline, let compare {
                    if baseline.id == compare.id {
                        Text("Select two different runs to compare")
                            .font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Divider()
                        ComparisonDiffView(baseline: baseline, compare: compare, showPassing: showPassing)
                        Toggle("Show passing tests", isOn: $showPassing)
                            .font(.caption)
                            .toggleStyle(.checkbox)
                    }
                } else {
                    Text("Pick a baseline and a comparison run above")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if baselineID == nil, store.testRuns.count >= 2 {
                    // Auto-select: second-most-recent as baseline, most-recent as compare
                    let sorted = store.testRuns.sorted { $0.date < $1.date }
                    baselineID = sorted[sorted.count - 2].id
                    compareID  = sorted[sorted.count - 1].id
                }
            }
        }
    }

    // MARK: - Diff view

    struct ComparisonDiffView: View {
        let baseline: TestRun
        let compare:  TestRun
        let showPassing: Bool

        enum DiffStatus { case regressed, stillFailing, fixed, added, removed, passing }

        struct DiffEntry: Identifiable {
            let id = UUID()
            let name: String
            let status: DiffStatus
            let before: TestCase.TestCaseStatus?
            let after:  TestCase.TestCaseStatus?
        }

        private var allEntries: [DiffEntry] {
            let baseMap    = Dictionary(uniqueKeysWithValues: baseline.testCases.map { ($0.name, $0) })
            let compareMap = Dictionary(uniqueKeysWithValues: compare.testCases.map  { ($0.name, $0) })
            var result: [DiffEntry] = []

            for tc in compare.testCases {
                if let base = baseMap[tc.name] {
                    let s: DiffStatus
                    if base.status == .passed && tc.status == .failed  { s = .regressed }
                    else if base.status == .failed && tc.status == .passed { s = .fixed }
                    else if base.status == .failed && tc.status == .failed { s = .stillFailing }
                    else { s = .passing }
                    result.append(DiffEntry(name: tc.name, status: s, before: base.status, after: tc.status))
                } else {
                    result.append(DiffEntry(name: tc.name, status: .added, before: nil, after: tc.status))
                }
            }
            for tc in baseline.testCases where compareMap[tc.name] == nil {
                result.append(DiffEntry(name: tc.name, status: .removed, before: tc.status, after: nil))
            }
            return result.sorted { order($0.status) < order($1.status) }
        }

        private func order(_ s: DiffStatus) -> Int {
            switch s {
            case .regressed: return 0; case .stillFailing: return 1; case .fixed: return 2
            case .added: return 3; case .removed: return 4; case .passing: return 5
            }
        }

        private var displayed: [DiffEntry] {
            showPassing ? allEntries : allEntries.filter { $0.status != .passing }
        }

        private var regressions:   Int { allEntries.filter { $0.status == .regressed    }.count }
        private var fixes:         Int { allEntries.filter { $0.status == .fixed        }.count }
        private var stillFailing:  Int { allEntries.filter { $0.status == .stillFailing }.count }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                // Summary bar
                HStack(spacing: 8) {
                    if regressions > 0 {
                        DiffPill(count: regressions, label: "Regressed",     color: .red,    icon: "arrow.down.circle.fill")
                    }
                    if fixes > 0 {
                        DiffPill(count: fixes,       label: "Fixed",         color: .green,  icon: "checkmark.circle.fill")
                    }
                    if stillFailing > 0 {
                        DiffPill(count: stillFailing, label: "Still Failing", color: .orange, icon: "exclamationmark.circle.fill")
                    }
                    if regressions == 0 && fixes == 0 && stillFailing == 0 {
                        Label("No regressions", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold)).foregroundStyle(.green)
                    }
                    Spacer()
                    let delta = compare.passRate - baseline.passRate
                    HStack(spacing: 3) {
                        Image(systemName: delta >= 0 ? "arrow.up" : "arrow.down")
                        Text(String(format: "%.0f%% → %.0f%%", baseline.passRate, compare.passRate))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(delta >= 0 ? Color.green : Color.red)
                }

                if displayed.isEmpty {
                    Text("All tests passing in both runs")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(displayed.enumerated()), id: \.element.id) { idx, entry in
                            DiffRow(entry: entry)
                            if idx < displayed.count - 1 {
                                Divider().padding(.leading, 28)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Diff row

    private struct DiffRow: View {
        let entry: ComparisonDiffView.DiffEntry

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(entry.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 5) {
                    if let b = entry.before { statusBadge(b) }
                    if entry.before != nil && entry.after != nil {
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    }
                    if let a = entry.after { statusBadge(a) }
                }
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 6)
        }

        private var icon: String {
            switch entry.status {
            case .regressed:    return "arrow.down.circle.fill"
            case .fixed:        return "checkmark.circle.fill"
            case .stillFailing: return "exclamationmark.circle.fill"
            case .passing:      return "checkmark.circle"
            case .added:        return "plus.circle.fill"
            case .removed:      return "minus.circle.fill"
            }
        }
        private var color: Color {
            switch entry.status {
            case .regressed:    return .red
            case .fixed:        return .green
            case .stillFailing: return .orange
            case .passing:      return .secondary
            case .added:        return .blue
            case .removed:      return .secondary
            }
        }
        private var label: String {
            switch entry.status {
            case .regressed:    return "Regressed"
            case .fixed:        return "Fixed"
            case .stillFailing: return "Still Failing"
            case .passing:      return "Passing"
            case .added:        return "New"
            case .removed:      return "Removed"
            }
        }

        @ViewBuilder
        private func statusBadge(_ s: TestCase.TestCaseStatus) -> some View {
            Text(s.rawValue.capitalized)
                .font(.caption2)
                .foregroundStyle(s == .passed ? Color.green : s == .failed ? Color.red : .secondary)
        }
    }

    // MARK: - Diff pill

    private struct DiffPill: View {
        let count: Int
        let label: String
        let color: Color
        let icon: String

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption)
                Text("\(count) \(label)").font(.caption.weight(.semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
        }
    }

// MARK: - Pass Rate Trend Chart

private struct PassRateTrendChart: View {
    let runs: [TestRun]  // must be sorted oldest → newest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                Text("Pass Rate Trend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                // Min / Max summary
                if let minRun = runs.min(by: { $0.passRate < $1.passRate }),
                   let maxRun = runs.max(by: { $0.passRate < $1.passRate }) {
                    HStack(spacing: 8) {
                        Label(String(format: "%.0f%%", minRun.passRate), systemImage: "arrow.down")
                            .font(.caption2).foregroundStyle(.red)
                        Label(String(format: "%.0f%%", maxRun.passRate), systemImage: "arrow.up")
                            .font(.caption2).foregroundStyle(.green)
                    }
                }
            }

            Chart {
                // 90% threshold
                RuleMark(y: .value("Good", 90))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("90%").font(.caption2).foregroundStyle(.green)
                    }
                // 70% threshold
                RuleMark(y: .value("Warning", 70))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("70%").font(.caption2).foregroundStyle(.orange)
                    }

                // Area fill
                ForEach(runs) { run in
                    AreaMark(
                        x: .value("Date", run.date),
                        y: .value("Pass Rate", run.passRate)
                    )
                    .foregroundStyle(.blue.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                }

                // Trend line
                ForEach(runs) { run in
                    LineMark(
                        x: .value("Date", run.date),
                        y: .value("Pass Rate", run.passRate)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                // Data points colored by pass rate
                ForEach(runs) { run in
                    PointMark(
                        x: .value("Date", run.date),
                        y: .value("Pass Rate", run.passRate)
                    )
                    .foregroundStyle(rateColor(run.passRate))
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel {
                        Text("\(val.as(Int.self) ?? 0)%").font(.caption2)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(runs.count, 5))) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .font(.caption2)
                }
            }
            .frame(height: 130)
        }
    }
}

// MARK: - JMeter Trend Chart

private struct JMeterTrendSection: View {
    @EnvironmentObject var store: AppStore

    private var sortedRuns: [JMeterRun] { store.jmeterRuns.sorted { $0.importedAt < $1.importedAt } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold)).foregroundStyle(.orange)
                Text("Pass Rate Trend")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let min = sortedRuns.min(by: { $0.passRate < $1.passRate }),
                   let max = sortedRuns.max(by: { $0.passRate < $1.passRate }) {
                    HStack(spacing: 8) {
                        Label(String(format: "%.0f%%", min.passRate), systemImage: "arrow.down")
                            .font(.caption2).foregroundStyle(.red)
                        Label(String(format: "%.0f%%", max.passRate), systemImage: "arrow.up")
                            .font(.caption2).foregroundStyle(.green)
                    }
                }
            }

            Chart {
                RuleMark(y: .value("95%", 95))
                    .foregroundStyle(.green.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("95%").font(.caption2).foregroundStyle(.green)
                    }
                RuleMark(y: .value("80%", 80))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                        Text("80%").font(.caption2).foregroundStyle(.orange)
                    }
                ForEach(sortedRuns) { run in
                    AreaMark(x: .value("Date", run.importedAt), y: .value("Pass Rate", run.passRate))
                        .foregroundStyle(.orange.opacity(0.08)).interpolationMethod(.catmullRom)
                }
                ForEach(sortedRuns) { run in
                    LineMark(x: .value("Date", run.importedAt), y: .value("Pass Rate", run.passRate))
                        .foregroundStyle(.orange).interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                }
                ForEach(sortedRuns) { run in
                    PointMark(x: .value("Date", run.importedAt), y: .value("Pass Rate", run.passRate))
                        .foregroundStyle(rateColor(run.passRate)).symbolSize(40)
                }
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { val in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                    AxisValueLabel { Text("\(val.as(Int.self) ?? 0)%").font(.caption2) }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(sortedRuns.count, 5))) {
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
            .frame(height: 130)
        }
    }
}

// MARK: - JMeter Run Comparison

private struct JMeterComparisonSection: View {
    @EnvironmentObject var store: AppStore
    @State private var baselineID: JMeterRun.ID?
    @State private var compareID:  JMeterRun.ID?

    private var baseline: JMeterRun? { store.jmeterRuns.first { $0.id == baselineID } }
    private var compare:  JMeterRun? { store.jmeterRuns.first { $0.id == compareID  } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Baseline").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Baseline", selection: $baselineID) {
                        Text("Select run…").tag(nil as JMeterRun.ID?)
                        ForEach(store.jmeterRuns) { run in Text(run.name).tag(run.id as JMeterRun.ID?) }
                    }.frame(maxWidth: .infinity)
                }
                Image(systemName: "arrow.right").foregroundStyle(.secondary).padding(.top, 18)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Compare").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Picker("Compare", selection: $compareID) {
                        Text("Select run…").tag(nil as JMeterRun.ID?)
                        ForEach(store.jmeterRuns) { run in Text(run.name).tag(run.id as JMeterRun.ID?) }
                    }.frame(maxWidth: .infinity)
                }
            }

            if let baseline, let compare, baseline.id != compare.id {
                Divider()
                JMeterDiffView(baseline: baseline, compare: compare)
            } else {
                Text("Pick two different runs to compare label-level results")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if baselineID == nil, store.jmeterRuns.count >= 2 {
                let sorted = store.jmeterRuns.sorted { $0.importedAt < $1.importedAt }
                baselineID = sorted[sorted.count - 2].id
                compareID  = sorted[sorted.count - 1].id
            }
        }
    }
}

private struct JMeterDiffView: View {
    let baseline: JMeterRun
    let compare:  JMeterRun

    struct LabelDiff: Identifiable {
        let id = UUID()
        let label:       String
        let basePass:    Double
        let comparePass: Double
        let baseAvgRT:   Double
        let compareAvgRT: Double
        var passDelta:   Double { comparePass - basePass }
        var rtDelta:     Double { compareAvgRT - baseAvgRT }
    }

    private func stats(for samples: [JMeterSample], label: String) -> (pass: Double, avgRT: Double) {
        let filtered = samples.filter { $0.label == label }
        guard !filtered.isEmpty else { return (0, 0) }
        let pass = Double(filtered.filter(\.success).count) / Double(filtered.count) * 100
        let rt   = filtered.map(\.responseTime).reduce(0, +) / Double(filtered.count) * 1000
        return (pass, rt)
    }

    private var diffs: [LabelDiff] {
        let allLabels = Set(baseline.samples.map(\.label)).union(compare.samples.map(\.label))
            .filter { $0 != "" }
        return allLabels.map { label in
            let b = stats(for: baseline.samples, label: label)
            let c = stats(for: compare.samples,  label: label)
            return LabelDiff(label: label, basePass: b.pass, comparePass: c.pass,
                             baseAvgRT: b.avgRT, compareAvgRT: c.avgRT)
        }
        .sorted { abs($0.passDelta) > abs($1.passDelta) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Label").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Pass Rate").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 130, alignment: .center)
                Text("Avg RT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: 110, alignment: .trailing)
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.quaternary)

            Divider()

            ForEach(diffs) { diff in
                HStack {
                    Text(diff.label).font(.subheadline).lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Text(String(format: "%.0f%%", diff.basePass))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", diff.comparePass))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(diff.passDelta > 0 ? .green : diff.passDelta < 0 ? .red : .primary)
                        if diff.passDelta != 0 {
                            Text(String(format: "%+.0f%%", diff.passDelta))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(diff.passDelta > 0 ? .green : .red)
                        }
                    }
                    .frame(width: 130, alignment: .center)

                    HStack(spacing: 4) {
                        Text(String(format: "%.0f ms", diff.compareAvgRT))
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        if abs(diff.rtDelta) > 1 {
                            Text(String(format: "%+.0f", diff.rtDelta))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(diff.rtDelta > 0 ? .red : .green)
                        }
                    }
                    .frame(width: 110, alignment: .trailing)
                }
                .padding(.horizontal, 12).padding(.vertical, 7)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1))
    }
}

#Preview {
    ReportsView()
        .environmentObject(AppStore())
}
