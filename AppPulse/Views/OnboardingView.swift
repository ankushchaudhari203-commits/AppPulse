import SwiftUI

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let bullets: [(icon: String, color: Color, text: String)]
}

private let pages: [OnboardingPage] = [
    OnboardingPage(
        icon: "app.badge.checkmark",
        iconColor: .blue,
        title: "Welcome to AppPulse",
        subtitle: "Your all-in-one QA dashboard for macOS. Monitor test results, track API health, run load tests, and generate test cases with AI — all in one place.",
        bullets: [
            ("checkmark.seal.fill",    .green,  "Run and import Xcode test results directly"),
            ("gauge.high",             .orange, "Run JMeter & Locust load tests headless or via GUI"),
            ("network",                .teal,   "Monitor API endpoint health in real time"),
            ("sparkles",               .purple, "Generate XCTest-ready test cases with Google Gemini AI"),
        ]
    ),
    OnboardingPage(
        icon: "square.grid.2x2",
        iconColor: .blue,
        title: "Overview",
        subtitle: "Your mission control. See all key metrics at a glance — pass rate, API health, load test status, and trends over time.",
        bullets: [
            ("testtube.2",             .blue,   "Total test runs and latest pass rate across all suites"),
            ("network",                .teal,   "API health summary across all monitored endpoints"),
            ("chart.xyaxis.line",      .orange, "Trends charts appear automatically once you have 3+ runs"),
            ("questionmark.circle",    .purple, "Help → AppPulse User Guide for JMeter & Locust parameter reference"),
        ]
    ),
    OnboardingPage(
        icon: "checkmark.circle",
        iconColor: .green,
        title: "Functional Tests",
        subtitle: "Run Xcode tests directly or import .xcresult bundles to track your test suite health over time.",
        bullets: [
            ("gearshape",              .gray,   "First, go to Settings → Tools and set your Xcode project path, scheme (e.g. MyApp), and destination"),
            ("play.fill",              .green,  "Click Run Tests to trigger xcodebuild — results import automatically"),
            ("plus.circle",            .blue,   "Or click + or drag & drop a .xcresult file to import manually"),
            ("chart.pie.fill",         .green,  "See pass rate ring, failed tests, and per-test-case drill-down"),
            ("arrow.down.doc",         .orange, "Export any run as a PDF report with ⌘E"),
        ]
    ),
    OnboardingPage(
        icon: "gauge.high",
        iconColor: .orange,
        title: "Performance Testing",
        subtitle: "Two powerful load testing tools in one tab — switch between JMeter and Locust using the picker in the sidebar.",
        bullets: [
            ("bolt.fill",              .yellow, "Quick Load Test: enter any URL, pick HTTP (GET/POST/PUT/DELETE/PATCH) or WebSocket — no .jmx file needed"),
            ("lock.shield",            .blue,   "Quick Test supports auth: Bearer Token, API Key, Basic Auth, or Custom Header"),
            ("play.fill",              .orange, "JMeter: click Run .jmx to run a test plan headless — results auto-import"),
            ("ant.fill",               .green,  "Locust: pick a locustfile.py, set users & spawn rate, AppPulse starts the test"),
            ("chart.xyaxis.line",      .purple, "Live Locust charts: RPS, response time, active users, fail ratio"),
        ]
    ),
    OnboardingPage(
        icon: "network",
        iconColor: .teal,
        title: "API Health",
        subtitle: "Add any HTTP/HTTPS endpoint and AppPulse will ping it on demand — or automatically on a schedule you set in Settings.",
        bullets: [
            ("plus",                   .teal,   "Add endpoints with the + button (e.g. https://api.example.com/health)"),
            ("circle.fill",            .green,  "Green = healthy (2xx),  Orange = degraded,  Red = down"),
            ("clock.arrow.2.circlepath", .blue, "Set auto-refresh interval in Settings → General"),
            ("bell",                   .orange, "Get notified when an endpoint goes down or recovers"),
        ]
    ),
    OnboardingPage(
        icon: "sparkles",
        iconColor: .purple,
        title: "AI Test Generation",
        subtitle: "Describe a user story and Google Gemini generates a complete suite of positive and negative test cases in seconds.",
        bullets: [
            ("key",                    .purple, "Paste your Gemini API key in Settings → AI / Gemini (free at aistudio.google.com)"),
            ("text.alignleft",         .blue,   "Type a user story — optionally add acceptance criteria or scenarios"),
            ("chevron.left.forwardslash.chevron.right", .green, "Export as XCTest Swift code — ready to paste into Xcode"),
            ("arrow.down.doc",         .orange, "Or export the full suite to CSV for any test management tool"),
        ]
    ),
    OnboardingPage(
        icon: "folder.badge.gearshape",
        iconColor: .mint,
        title: "CI Watch & Reports",
        subtitle: "Connect AppPulse to your CI pipeline and get instant visibility without any manual steps.",
        bullets: [
            ("folder.badge.gearshape", .mint,   "CI Watch: point AppPulse at a folder — new .xcresult & .jtl files auto-import"),
            ("doc.text",               .indigo, "Reports: view pass rate trends, run comparisons, and export HTML or PDF"),
            ("bell.badge",             .orange, "Notifications: get macOS alerts when any test run or JMeter run completes"),
            ("link",                   .green,  "Slack: post run summaries to your team channel via webhook"),
        ]
    ),
    OnboardingPage(
        icon: "gearshape",
        iconColor: .secondary,
        title: "Settings  (⌘,)",
        subtitle: "Configure AppPulse once and everything stays in sync across all tabs.",
        bullets: [
            ("wrench.and.screwdriver", .orange, "Tools: set your Xcode project & scheme for one-click test runs"),
            ("paintbrush",             .blue,   "General: choose Light, Dark, or System appearance; set API health auto-refresh"),
            ("sparkles",               .purple, "AI / Gemini: save your API key and preferred Gemini model"),
            ("cylinder",               .red,    "Data: clear runs, endpoints, or AI suites — or backup and restore everything"),
        ]
    ),
]

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isVisible: Bool
    @State private var currentPage = 0
    @State private var direction: Int = 1

    private var isLast: Bool { currentPage == pages.count - 1 }
    private var page: OnboardingPage { pages[currentPage] }

    var body: some View {
        ZStack {
            // Vibrant gradient background
            LinearGradient(
                stops: [
                    .init(color: page.iconColor.opacity(0.28), location: 0),
                    .init(color: page.iconColor.opacity(0.10), location: 0.45),
                    .init(color: Color(NSColor.windowBackgroundColor), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.4), value: currentPage)

            // Decorative blurred circle top-right
            Circle()
                .fill(page.iconColor.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 180, y: -130)
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            // Decorative blurred circle bottom-left
            Circle()
                .fill(page.iconColor.opacity(0.10))
                .frame(width: 200, height: 200)
                .blur(radius: 30)
                .offset(x: -160, y: 160)
                .animation(.easeInOut(duration: 0.4), value: currentPage)

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if !isLast {
                        Button("Skip") { finish() }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                    } else {
                        Color.clear.frame(height: 34).padding(.top, 16)
                    }
                }

                // Page content
                PageContent(page: page, direction: direction)
                    .id(currentPage)
                    .transition(.asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: direction > 0 ? .leading  : .trailing).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: currentPage)

                Spacer(minLength: 0)

                // Bottom bar
                VStack(spacing: 16) {
                    // Progress dots
                    HStack(spacing: 7) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? page.iconColor : Color.secondary.opacity(0.25))
                                .frame(width: i == currentPage ? 22 : 7, height: 7)
                                .animation(.spring(duration: 0.3), value: currentPage)
                        }
                    }

                    HStack(spacing: 12) {
                        if currentPage > 0 {
                            Button {
                                direction = -1
                                withAnimation { currentPage -= 1 }
                            } label: {
                                Label("Back", systemImage: "chevron.left")
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Color.clear.frame(width: 80, height: 32)
                        }

                        Spacer()

                        Button {
                            if isLast { finish() } else {
                                direction = 1
                                withAnimation { currentPage += 1 }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(isLast ? "Get Started" : "Next")
                                    .fontWeight(.semibold)
                                Image(systemName: isLast ? "checkmark" : "chevron.right")
                            }
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(page.iconColor)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                    .padding(.horizontal, 28)
                }
                .padding(.bottom, 24)
            }
        }
        .frame(width: 560, height: 460)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        withAnimation(.easeOut(duration: 0.3)) { isVisible = false }
    }
}

// MARK: - Single Page Content

private struct PageContent: View {
    let page: OnboardingPage
    let direction: Int

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: page.icon)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(page.iconColor)
            }

            // Title + subtitle
            VStack(spacing: 10) {
                Text(page.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(page.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 460)
            }

            // Bullets
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(page.bullets.enumerated()), id: \.offset) { _, bullet in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: bullet.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(bullet.color)
                            .frame(width: 20)
                        Text(bullet.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: 500, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .padding(.top, 12)
    }
}

#Preview {
    OnboardingView(isVisible: .constant(true))
}
