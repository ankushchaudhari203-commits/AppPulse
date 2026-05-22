import SwiftUI
import Charts

// MARK: - Main View

struct APIHealthView: View {
    @EnvironmentObject var store: AppStore
    @State private var newEndpoint = ""
    @State private var selectedEndpoint: String?

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                if !store.healthChecks.isEmpty {
                    HealthSummaryBanner()
                    Divider()
                }
                List(selection: $selectedEndpoint) {
                    ForEach(store.healthChecks) { check in
                        HealthCheckRow(
                            check: check,
                            history: store.healthHistory[check.endpoint] ?? []
                        )
                        .tag(check.endpoint)
                    }
                    .onDelete { store.removeEndpoints(at: $0) }
                }
                .listStyle(.sidebar)
                .overlay {
                    if store.monitoredEndpoints.isEmpty { emptyState }
                }
                addEndpointBar
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300)
            .navigationTitle("API Health")
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
                    .disabled(store.isRefreshing || store.monitoredEndpoints.isEmpty)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh all endpoints (⌘R)")
                }
            }
        } detail: {
            if let endpoint = selectedEndpoint,
               let check = store.healthChecks.first(where: { $0.endpoint == endpoint }) {
                EndpointDetailView(
                    check: check,
                    history: store.healthHistory[endpoint] ?? []
                )
            } else {
                emptyDetail
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No endpoints monitored")
                .font(.headline)
            Text("Add an endpoint below to start health checks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyDetail: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Select an endpoint")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("History and response time charts will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addEndpointBar: some View {
        HStack(spacing: 8) {
            TextField("https://api.example.com/health", text: $newEndpoint)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addEndpoint() }
            Button("Add", action: addEndpoint)
                .disabled(newEndpoint.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(.bar)
    }

    private func addEndpoint() {
        let url = newEndpoint.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        store.addEndpoint(url)
        newEndpoint = ""
        Task { await store.refresh() }
    }
}

// MARK: - Endpoint Detail

struct EndpointDetailView: View {
    let check: HealthCheck
    let history: [HealthCheckEvent]

    private var recentEvents: [HealthCheckEvent] { Array(history.suffix(50)) }

    private var uptimePercent: Double {
        guard !history.isEmpty else { return 0 }
        let healthy = history.filter { $0.status == .healthy }.count
        return Double(healthy) / Double(history.count) * 100
    }

    private var avgResponseTime: Double {
        let timed = history.filter { $0.responseTime > 0 }
        guard !timed.isEmpty else { return 0 }
        return timed.map(\.responseTime).reduce(0, +) / Double(timed.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                EndpointDetailHeader(check: check, uptime: uptimePercent, avgRT: avgResponseTime)

                if !history.isEmpty {
                    ResponseTimeChart(events: recentEvents)
                    EventLogTable(events: Array(recentEvents.reversed()))
                } else {
                    Text("No history yet — run a health check to start collecting data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(20)
        }
        .navigationTitle(URL(string: check.endpoint)?.host ?? check.endpoint)
    }
}

// MARK: - Detail Header

struct EndpointDetailHeader: View {
    let check: HealthCheck
    let uptime: Double
    let avgRT: Double

    private var statusColor: Color { healthColor(check.status) }
    private var statusLabel: String { healthLabel(check.status) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusLabel)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                Text(check.endpoint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 16) {
                if !check.endpoint.isEmpty {
                    DetailStatBox(
                        label: "Uptime",
                        value: String(format: "%.1f%%", uptime),
                        color: uptime >= 99 ? .green : uptime >= 90 ? .orange : .red
                    )
                }
                if let code = check.statusCode {
                    DetailStatBox(
                        label: "HTTP Status",
                        value: "\(code)",
                        color: code < 300 ? .green : code < 500 ? .orange : .red
                    )
                }
                if check.responseTime > 0 {
                    let ms = check.responseTime * 1000
                    DetailStatBox(
                        label: "Last RT",
                        value: ms < 1000 ? String(format: "%.0f ms", ms) : String(format: "%.2f s", check.responseTime),
                        color: ms < 200 ? .green : ms < 1000 ? .orange : .red
                    )
                }
                if avgRT > 0 {
                    let ms = avgRT * 1000
                    DetailStatBox(
                        label: "Avg RT",
                        value: ms < 1000 ? String(format: "%.0f ms", ms) : String(format: "%.2f s", avgRT),
                        color: ms < 200 ? .green : ms < 1000 ? .orange : .red
                    )
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

struct DetailStatBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
        .padding(12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Response Time Chart

struct ResponseTimeChart: View {
    let events: [HealthCheckEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Response Time — last \(events.count) checks")
                .font(.subheadline.weight(.semibold))

            Chart {
                ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                    if event.responseTime > 0 {
                        LineMark(
                            x: .value("Check", idx),
                            y: .value("ms", event.responseTime * 1000)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Check", idx),
                            y: .value("ms", event.responseTime * 1000)
                        )
                        .foregroundStyle(.blue.opacity(0.08))
                        .interpolationMethod(.catmullRom)
                    }
                }

                RuleMark(y: .value("1s threshold", 1000))
                    .foregroundStyle(.red.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing) {
                        Text("1s").font(.caption2).foregroundStyle(.red)
                    }

                RuleMark(y: .value("200ms threshold", 200))
                    .foregroundStyle(.orange.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .trailing) {
                        Text("200ms").font(.caption2).foregroundStyle(.orange)
                    }
            }
            .chartYAxisLabel("ms")
            .chartXAxis(.hidden)
            .frame(height: 150)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Event Log

struct EventLogTable: View {
    let events: [HealthCheckEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Log")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 0) {
                HStack {
                    Text("Time")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Status")
                        .frame(width: 90, alignment: .leading)
                    Text("HTTP")
                        .frame(width: 55, alignment: .trailing)
                    Text("Response Time")
                        .frame(width: 110, alignment: .trailing)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.quaternary)

                Divider()

                ForEach(events) { event in
                    EventLogRow(event: event)
                    Divider()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 1))
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.07), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

struct EventLogRow: View {
    let event: HealthCheckEvent

    private var statusColor: Color { healthColor(event.status) }
    private var statusLabel: String { healthLabel(event.status) }

    private var rtLabel: String {
        guard event.responseTime > 0 else { return "—" }
        let ms = event.responseTime * 1000
        return ms < 1000 ? String(format: "%.0f ms", ms) : String(format: "%.2f s", event.responseTime)
    }

    var body: some View {
        HStack {
            Text(event.date, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusLabel).foregroundStyle(statusColor)
            }
            .font(.caption.weight(.medium))
            .frame(width: 90, alignment: .leading)

            Group {
                if let code = event.statusCode {
                    Text("\(code)")
                        .foregroundStyle(code < 300 ? .green : code < 500 ? .orange : .red)
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospacedDigit())
            .frame(width: 55, alignment: .trailing)

            Text(rtLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

// MARK: - Summary Banner

struct HealthSummaryBanner: View {
    @EnvironmentObject var store: AppStore

    private var total:    Int { store.healthChecks.count }
    private var healthy:  Int { store.healthChecks.filter { $0.status == .healthy  }.count }
    private var down:     Int { store.healthChecks.filter { $0.status == .down     }.count }
    private var degraded: Int { store.healthChecks.filter { $0.status == .degraded }.count }

    private var overallColor: Color {
        if down > 0 { return .red }
        if degraded > 0 { return .orange }
        if healthy == total && total > 0 { return .green }
        return .secondary
    }

    private var overallLabel: String {
        if total == 0 { return "No endpoints" }
        if down > 0 { return "\(down) endpoint\(down > 1 ? "s" : "") down" }
        if degraded > 0 { return "\(degraded) endpoint\(degraded > 1 ? "s" : "") degraded" }
        return "All endpoints healthy"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(overallColor)
                    .frame(width: 8, height: 8)
                Text(overallLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(overallColor)
                    .lineLimit(1)
                Spacer()
                Text("\(healthy)/\(total) healthy")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                SummaryPill(count: healthy, label: "Healthy", color: .green)
                if degraded > 0 {
                    SummaryPill(count: degraded, label: "Degraded", color: .orange)
                }
                if down > 0 {
                    SummaryPill(count: down, label: "Down", color: .red)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct SummaryPill: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Health Check Row (with sparkline)

struct HealthCheckRow: View {
    let check: HealthCheck
    let history: [HealthCheckEvent]

    var body: some View {
        HStack(spacing: 10) {
            // Status badge
            HStack(spacing: 5) {
                Circle()
                    .fill(healthColor(check.status))
                    .frame(width: 7, height: 7)
                Text(healthLabel(check.status))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(healthColor(check.status))
                    .lineLimit(1)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(healthColor(check.status).opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .fixedSize()

            // Endpoint info
            VStack(alignment: .leading, spacing: 2) {
                Text(URL(string: check.endpoint)?.host ?? check.endpoint)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(check.lastChecked.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Sparkline
            HealthSparkline(events: history)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Health Sparkline

struct HealthSparkline: View {
    let events: [HealthCheckEvent]

    private var slots: [HealthCheckEvent?] {
        let recent = Array(events.suffix(15))
        let padding = Array(repeating: nil as HealthCheckEvent?, count: max(0, 15 - recent.count))
        return padding + recent.map { Optional($0) }
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<15, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(slots[i].map { healthColor($0.status) } ?? Color.secondary.opacity(0.15))
                    .frame(width: 3, height: 14)
            }
        }
        .fixedSize()
    }
}

// MARK: - Shared helpers

private func healthColor(_ status: HealthCheck.HealthStatus) -> Color {
    switch status {
    case .healthy:  return .green
    case .degraded: return .orange
    case .down:     return .red
    case .unknown:  return .secondary
    }
}

private func healthLabel(_ status: HealthCheck.HealthStatus) -> String {
    switch status {
    case .healthy:  return "Healthy"
    case .degraded: return "Degraded"
    case .down:     return "Down"
    case .unknown:  return "Unknown"
    }
}

private func httpCodeLabel(_ code: Int) -> String {
    let map: [Int: String] = [
        200: "200 OK", 201: "201 Created", 204: "204 No Content",
        301: "301 Moved", 302: "302 Found",
        400: "400 Bad Request", 401: "401 Unauthorized",
        403: "403 Forbidden", 404: "404 Not Found",
        500: "500 Server Error", 502: "502 Bad Gateway",
        503: "503 Unavailable", 504: "504 Timeout"
    ]
    return map[code] ?? "\(code)"
}

#Preview {
    APIHealthView()
        .environmentObject(AppStore())
}
