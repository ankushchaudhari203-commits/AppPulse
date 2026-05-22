import SwiftUI
import Charts

// MARK: - Supporting Types

struct TimeBucket: Identifiable {
    let id = UUID()
    var time: Date
    var avgRT: Double
    var rps: Double
    var errorRate: Double
}

struct CodeCount: Identifiable {
    let id = UUID()
    var code: String
    var count: Int
}

// MARK: - Charts View

struct JMeterChartsView: View {
    let samples: [JMeterSample]

    private var buckets: [TimeBucket] { makeTimeBuckets() }
    private var codeCounts: [CodeCount] { makeCodeCounts() }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                responseTimeChart
                throughputChart
                codeDistributionChart
            }
            .padding()
        }
    }

    // MARK: - Chart 1: Response Time Over Time

    private var responseTimeChart: some View {
        ChartCard(title: "Response Time Over Time", subtitle: "avg ms per interval") {
            if buckets.isEmpty {
                noDataLabel
            } else {
                Chart(buckets) { bucket in
                    AreaMark(
                        x: .value("Time", bucket.time),
                        y: .value("Avg RT (ms)", bucket.avgRT)
                    )
                    .foregroundStyle(.purple.opacity(0.15))
                    LineMark(
                        x: .value("Time", bucket.time),
                        y: .value("Avg RT (ms)", bucket.avgRT)
                    )
                    .foregroundStyle(.purple)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute().second())
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisGridLine(); AxisValueLabel() }
                }
                .chartYAxisLabel("ms", position: .leading)
                .frame(height: 180)
            }
        }
    }

    // MARK: - Chart 2: Throughput Over Time

    private var throughputChart: some View {
        ChartCard(title: "Throughput Over Time", subtitle: "requests per second") {
            if buckets.isEmpty {
                noDataLabel
            } else {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Time", bucket.time, unit: .second),
                        y: .value("Req/s", bucket.rps)
                    )
                    .foregroundStyle(
                        LinearGradient(colors: [.blue, .cyan], startPoint: .bottom, endPoint: .top)
                    )
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute().second())
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisGridLine(); AxisValueLabel() }
                }
                .chartYAxisLabel("req/s", position: .leading)
                .frame(height: 160)
            }
        }
    }

    // MARK: - Chart 3: Response Code Distribution

    private var codeDistributionChart: some View {
        ChartCard(title: "Response Code Distribution", subtitle: "count by HTTP status code") {
            if codeCounts.isEmpty {
                noDataLabel
            } else {
                Chart(codeCounts) { item in
                    BarMark(
                        x: .value("Code", item.code),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(codeColor(item.code).gradient)
                    .annotation(position: .top, alignment: .center) {
                        Text(formatCount(item.count))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { AxisGridLine(); AxisValueLabel() }
                }
                .chartYAxisLabel("count", position: .leading)
                .frame(height: 160)
            }
        }
    }

    private var noDataLabel: some View {
        Text("Not enough data to render chart")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    // MARK: - Helpers

    private func codeColor(_ code: String) -> Color {
        switch code.prefix(1) {
        case "2": return .green
        case "1": return .blue
        case "3": return .teal
        case "4": return .orange
        case "5": return .red
        default:  return .secondary
        }
    }

    private func formatCount(_ n: Int) -> String {
        n >= 1000 ? String(format: "%.1fk", Double(n) / 1000) : "\(n)"
    }

    // MARK: - Data Processing

    private func makeTimeBuckets(count: Int = 60) -> [TimeBucket] {
        guard samples.count > 1 else { return [] }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        let start = sorted.first!.timestamp.timeIntervalSince1970
        let end   = sorted.last!.timestamp.timeIntervalSince1970
        let duration = end - start
        guard duration > 0 else { return [] }
        let bucketSize = duration / Double(count)

        var buckets = Array(repeating: [JMeterSample](), count: count)
        for sample in sorted {
            let idx = min(Int((sample.timestamp.timeIntervalSince1970 - start) / bucketSize), count - 1)
            buckets[idx].append(sample)
        }

        return buckets.enumerated().compactMap { i, items -> TimeBucket? in
            guard !items.isEmpty else { return nil }
            let time     = Date(timeIntervalSince1970: start + Double(i) * bucketSize)
            let avgRT    = items.map(\.responseTime).reduce(0, +) / Double(items.count) * 1000
            let rps      = Double(items.count) / bucketSize
            let errRate  = Double(items.filter { !$0.success }.count) / Double(items.count) * 100
            return TimeBucket(time: time, avgRT: avgRT, rps: rps, errorRate: errRate)
        }
    }

    private func makeCodeCounts() -> [CodeCount] {
        var counts: [String: Int] = [:]
        for sample in samples {
            let code = sample.responseCode.isEmpty ? "N/A" : sample.responseCode
            counts[code, default: 0] += 1
        }
        return counts
            .map { CodeCount(code: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Card Container

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.07), radius: 5, y: 2)
    }
}
