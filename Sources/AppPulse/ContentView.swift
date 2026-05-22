import SwiftUI

struct ContentView: View {
    @State private var selectedSection: Section = .overview

    enum Section: String, CaseIterable {
        case overview      = "Overview"
        case functional    = "Functional Tests"
        case performance   = "Performance"
        case apiHealth     = "API Health"
        case reports       = "Reports"

        var icon: String {
            switch self {
            case .overview:   return "gauge.with.dots.needle.67percent"
            case .functional: return "checkmark.seal"
            case .performance: return "bolt.horizontal"
            case .apiHealth:  return "antenna.radiowaves.left.and.right"
            case .reports:    return "doc.text"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.icon)
            }
            .navigationSplitViewColumnWidth(200)
            .listStyle(.sidebar)
        } detail: {
            switch selectedSection {
            case .overview:    OverviewView()
            case .functional:  FunctionalTestsView()
            case .performance: PerformanceView()
            case .apiHealth:   APIHealthView()
            case .reports:     ReportsView()
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}
