import SwiftUI

@main
struct AppPulseApp: App {
    @StateObject private var store = AppStore()
    @State private var showSplash = true
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @AppStorage("appearanceMode")         private var appearanceMode = "system"
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var preferredScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(selectedTab: $selectedTab)
                    .environmentObject(store)
                    .opacity(showSplash ? 0 : 1)

                if showSplash {
                    SplashView(isVisible: $showSplash)
                        .transition(.opacity)
                        .zIndex(1)
                        .onDisappear {
                            if !hasCompletedOnboarding { showOnboarding = true }
                        }
                }

                if showOnboarding {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                        .zIndex(2)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            OnboardingView(isVisible: $showOnboarding)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.3), radius: 24, x: 0, y: 8)
                                .transition(.scale(scale: 0.96).combined(with: .opacity))
                            Spacer()
                        }
                        Spacer()
                    }
                    .zIndex(3)
                }
            }
            .animation(.easeOut(duration: 0.4), value: showSplash)
            .animation(.spring(duration: 0.35), value: showOnboarding)
            .preferredColorScheme(preferredScheme)
            .onReceive(NotificationCenter.default.publisher(for: .showOnboarding)) { _ in
                showOnboarding = true
            }
        }
        .defaultSize(width: 1006, height: 534)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About AppPulse") {
                    let options: [NSApplication.AboutPanelOptionKey: Any] = [
                        .applicationName: "AppPulse",
                        .credits: NSAttributedString(
                            string: "Quality Engineering Dashboard for macOS\nFunctional Tests · Load Testing · API Health · AI Generation",
                            attributes: [
                                .font: NSFont.systemFont(ofSize: 11),
                                .foregroundColor: NSColor.secondaryLabelColor
                            ]
                        ),
                        .version: "1.0"
                    ]
                    NSApp.orderFrontStandardAboutPanel(options)
                }
            }
            CommandGroup(replacing: .help) {
                OpenGuideButton()
                Button("Show Onboarding…") {
                    UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                    NotificationCenter.default.post(name: .showOnboarding, object: nil)
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

extension Notification.Name {
    static let showOnboarding = Notification.Name("AppPulse.showOnboarding")
}

private struct OpenGuideButton: View {
    var body: some View {
        Button("AppPulse User Guide") {
            let controller = NSHostingController(rootView: UserGuideView())
            let window = NSWindow(contentViewController: controller)
            window.title = "AppPulse User Guide"
            window.setContentSize(NSSize(width: 560, height: 600))
            window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
            window.center()
            window.makeKeyAndOrderFront(nil)
        }
        .keyboardShortcut("/", modifiers: .command)
    }
}
