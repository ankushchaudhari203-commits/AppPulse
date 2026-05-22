import SwiftUI

struct UserGuideView: View {
    @State private var selectedTool = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            HStack {
                Picker("", selection: $selectedTool) {
                    Text("JMeter").tag(0)
                    Text("Locust").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(14)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            ScrollView {
                if selectedTool == 0 {
                    JMeterGuideContent()
                } else {
                    LocustGuideContent()
                }
            }
        }
        .frame(width: 560, height: 600)
    }
}

// MARK: - JMeter

private struct JMeterGuideContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            GuideSection(title: "How to use JMeter", icon: "bolt.horizontal", color: .blue) {
                GuideStep(number: 1, text: "Go to **Performance → JMeter** tab and click **⚡ Launch JMeter** to open the GUI.")
                GuideStep(number: 2, text: "In JMeter, open or create a Test Plan (.jmx file) and configure your HTTP requests.")
                GuideStep(number: 3, text: "Add a **Listener → Simple Data Writer** and set the output file to a `.jtl` path.")
                GuideStep(number: 4, text: "Run the test. JMeter writes results to the .jtl file automatically.")
                GuideStep(number: 5, text: "Back in AppPulse, click **Import .jtl** and select your results file to view the report.")
            }

            Divider()

            GuideSection(title: "Reading Parameters", icon: "chart.bar.doc.horizontal", color: .purple) {
                GuideParam(name: "Pass Rate",     color: .green,  description: "% of requests that returned a 2xx HTTP status. Aim for 95%+.")
                GuideParam(name: "Avg RT",        color: .purple, description: "Average response time in ms across all samples.")
                GuideParam(name: "Samples",       color: .blue,   description: "Total number of HTTP requests executed during the test.")
                GuideParam(name: "Throughput",    color: .teal,   description: "Requests per second processed by the server.")
                GuideParam(name: "Error %",       color: .red,    description: "Percentage of requests that failed (non-2xx or timeout).")
                GuideParam(name: "Response Code", color: .orange, description: "HTTP status returned: 2xx = success, 4xx = client error, 5xx = server error.")
            }

            Divider()

            GuideSection(title: "Good vs Bad Thresholds", icon: "gauge.with.dots.needle.50percent", color: .orange) {
                ThresholdRow(metric: "Pass Rate", good: "≥ 95%",    warning: "80–94%",   bad: "< 80%")
                ThresholdRow(metric: "Avg RT",    good: "< 300 ms", warning: "300ms–1s", bad: "> 1s")
                ThresholdRow(metric: "Error %",   good: "0%",       warning: "< 2%",     bad: "> 2%")
            }
        }
        .padding(20)
    }
}

// MARK: - Locust

private struct LocustGuideContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            GuideSection(title: "How to use Locust", icon: "ant.fill", color: .green) {
                GuideStep(number: 1, text: "Go to **Performance → Locust** tab and click **Launch Locust**.")
                GuideStep(number: 2, text: "Browse to your `locustfile.py`, set the **Target Host** (e.g. https://api.example.com).")
                GuideStep(number: 3, text: "Set **Number of Users** (concurrent virtual users) and **Spawn Rate** (users added per second).")
                GuideStep(number: 4, text: "Click **Launch** — AppPulse starts Locust and auto-triggers the test.")
                GuideStep(number: 5, text: "Watch live stats in the **Overview**, **Stats**, and **Charts** tabs.")
                GuideStep(number: 6, text: "Click **Stop Locust** when done or open the **Web UI** for Locust's built-in report.")
            }

            Divider()

            GuideSection(title: "Reading Parameters", icon: "chart.xyaxis.line", color: .orange) {
                GuideParam(name: "RPS",          color: .blue,   description: "Requests Per Second — throughput of your load test in real time.")
                GuideParam(name: "Users",        color: .purple, description: "Number of concurrent virtual users currently active.")
                GuideParam(name: "Fail Ratio",   color: .red,    description: "Fraction of requests that failed. 0 = all passing.")
                GuideParam(name: "Avg RT",       color: .teal,   description: "Mean response time across all requests (ms).")
                GuideParam(name: "Min / Max RT", color: .green,  description: "Fastest and slowest individual request times (ms).")
                GuideParam(name: "Median RT",    color: .indigo, description: "Middle value — less skewed by outliers than the average.")
                GuideParam(name: "95th %ile",    color: .orange, description: "95% of requests completed faster than this value. Key SLA metric.")
                GuideParam(name: "99th %ile",    color: .red,    description: "Worst-case for 99% of requests. Highlights tail latency issues.")
                GuideParam(name: "Spawn Rate",   color: .blue,   description: "Users added per second until the target user count is reached.")
            }

            Divider()

            GuideSection(title: "Good vs Bad Thresholds", icon: "gauge.with.dots.needle.50percent", color: .orange) {
                ThresholdRow(metric: "Fail Ratio", good: "0%",       warning: "< 1%",    bad: "> 1%")
                ThresholdRow(metric: "Avg RT",     good: "< 300 ms", warning: "300ms–1s", bad: "> 1s")
                ThresholdRow(metric: "95th %ile",  good: "< 500 ms", warning: "500ms–2s", bad: "> 2s")
            }
        }
        .padding(20)
    }
}

// MARK: - Shared components

private struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(color).font(.subheadline)
                Text(title).font(.subheadline.weight(.semibold))
            }
            content()
        }
    }
}

private struct GuideStep: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideParam: View {
    let name: String
    let color: Color
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(name)
                .font(.callout.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 100, alignment: .leading)
                .fixedSize()
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ThresholdRow: View {
    let metric: String
    let good: String
    let warning: String
    let bad: String

    var body: some View {
        HStack(spacing: 8) {
            Text(metric)
                .font(.callout.weight(.medium))
                .frame(width: 90, alignment: .leading)
            ThresholdChip(label: good,    color: .green)
            ThresholdChip(label: warning, color: .orange)
            ThresholdChip(label: bad,     color: .red)
        }
    }
}

private struct ThresholdChip: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    UserGuideView()
}
