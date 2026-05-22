import SwiftUI
import Charts

struct StatCard: View {
    var title: String
    var value: String
    var subtitle: String
    var icon: String
    var color: Color
    var sparkline: [Double] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if sparkline.count >= 2 {
                MiniSparkline(data: sparkline, color: color)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Mini Sparkline

struct MiniSparkline: View {
    let data: [Double]
    let color: Color

    private var points: [(index: Int, value: Double)] {
        data.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        Chart {
            ForEach(points, id: \.index) { pt in
                AreaMark(
                    x: .value("i", pt.index),
                    y: .value("v", pt.value)
                )
                .foregroundStyle(color.opacity(0.25))
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("i", pt.index),
                    y: .value("v", pt.value)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 36)
    }
}

#Preview {
    HStack {
        StatCard(title: "Pass Rate", value: "94%", subtitle: "47 passed",
                 icon: "checkmark.seal.fill", color: .green,
                 sparkline: [72, 80, 85, 78, 90, 88, 94])
        StatCard(title: "API Health", value: "3/4", subtitle: "endpoints healthy",
                 icon: "network", color: .orange,
                 sparkline: [100, 100, 75, 75, 100, 100, 75])
    }
    .padding()
}
