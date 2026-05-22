import SwiftUI

struct APIHealthView: View {
    @StateObject private var service = APIHealthService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("API Health")
                            .font(.largeTitle).bold()
                        Text("Are all services responding correctly?")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Auto-checks every 5 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await service.checkAll() }
                    } label: {
                        Label("Check Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if service.isChecking {
                    ProgressView("Checking services...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                GroupBox {
                    VStack(spacing: 0) {
                        ForEach(service.endpoints) { endpoint in
                            EndpointRow(endpoint: endpoint)
                            Divider()
                        }
                        if service.endpoints.isEmpty {
                            EmptyStateView(
                                icon: "antenna.radiowaves.left.and.right",
                                title: "No endpoints configured",
                                message: "Add your API endpoints in Settings"
                            )
                        }
                    }
                    .padding(4)
                }

                Button {
                    service.addEndpoint()
                } label: {
                    Label("Add Endpoint", systemImage: "plus.circle")
                }
            }
            .padding(24)
        }
        .navigationTitle("API Health")
        .task {
            await service.checkAll()
        }
    }
}

struct EndpointRow: View {
    let endpoint: APIEndpoint

    var statusIcon: String {
        switch endpoint.status {
        case .up:      return "circle.fill"
        case .down:    return "circle.fill"
        case .slow:    return "circle.fill"
        case .unknown: return "circle.dotted"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(endpoint.status.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(endpoint.name).font(.subheadline).bold()
                Text(endpoint.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(endpoint.status.label)
                .foregroundStyle(endpoint.status.color)
                .font(.subheadline)

            if let ms = endpoint.responseMs {
                Text("(\(ms)ms)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
