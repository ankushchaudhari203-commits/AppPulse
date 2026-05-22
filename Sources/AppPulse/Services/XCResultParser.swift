import Foundation
import Combine
import AppKit

@MainActor
class XCResultParser: ObservableObject {
    static let shared = XCResultParser()

    @Published var testSuites: [TestSuite] = []
    @Published var isLoading = false
    @Published var selectedFile: String?

    func selectResultFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.message = "Select an .xcresult file"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFile = url.path
            Task { await parse(url: url) }
        }
    }

    func runTests() async {
        isLoading = true
        defer { isLoading = false }

        let result = await shell("xcodebuild test -scheme AppPulse -destination 'platform=macOS' 2>&1 | tail -20")
        print(result)

        // After running, find latest .xcresult in DerivedData
        if let url = findLatestXCResult() {
            await parse(url: url)
        }
    }

    private func parse(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        let json = await shell("xcrun xcresulttool get --format json --path \"\(url.path)\"")
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        testSuites = parseSuites(from: root)
    }

    private func parseSuites(from root: [String: Any]) -> [TestSuite] {
        guard let actions = (root["actions"] as? [String: Any])?["_values"] as? [[String: Any]]
        else { return [] }

        var suites: [TestSuite] = []

        for action in actions {
            guard let tests = ((action["actionResult"] as? [String: Any])?
                ["testsRef"] as? [String: Any])?["id"] as? [String: Any]
            else { continue }
            _ = tests // detailed parsing requires a second xcresulttool call per ref
        }

        return suites
    }

    private func findLatestXCResult() -> URL? {
        let derivedData = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Developer/Xcode/DerivedData")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: derivedData, includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return nil }

        return contents
            .filter { $0.pathExtension == "xcresult" }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
            .first
    }
}
