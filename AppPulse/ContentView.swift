import SwiftUI

struct ContentView: View {
    @Binding var selectedTab: Int

    var body: some View {
        TabView(selection: $selectedTab) {
            OverviewView()
                .tabItem { Label("Overview",     systemImage: "square.grid.2x2") }
                .tag(0)
            FunctionalTestsView()
                .tabItem { Label("Functional",   systemImage: "checkmark.circle") }
                .tag(1)
            PerformanceView()
                .tabItem { Label("Performance",  systemImage: "gauge.high") }
                .tag(2)
            APIHealthView()
                .tabItem { Label("API Health",   systemImage: "network") }
                .tag(3)
            TestGeneratorView()
                .tabItem { Label("AI Tests",     systemImage: "sparkles") }
                .tag(4)
            ReportsView()
                .tabItem { Label("Reports",      systemImage: "doc.text") }
                .tag(5)
        }
    }
}

#Preview {
    ContentView(selectedTab: .constant(0))
}

