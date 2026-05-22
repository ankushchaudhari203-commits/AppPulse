import Foundation
import Combine
import AppKit

@MainActor
class JMeterParser: ObservableObject {
    static let shared = JMeterParser()

    @Published var isRunning = false
    @Published var result: JMeterResult?
    @Published var selectedFile: String?

    private var process: Process?

    func selectFile() {
        let panel = NSOpenPanel()
        panel.message = "Select a JMeter test plan (.jmx)"
        panel.prompt = "Select"
        if panel.runModal() == .OK {
            selectedFile = panel.url?.path
        }
    }

    func run(users: Int, duration: Int) async {
        guard let jmxPath = selectedFile else { return }

        isRunning = true
        result = nil

        let outputPath = NSTemporaryDirectory() + "apppulse_results.jtl"
        let cmd = "jmeter -n -t \"\(jmxPath)\" -l \"\(outputPath)\" -Jthreads=\(users) -Jduration=\(duration * 60)"

        await shell(cmd)
        result = parseJTL(at: outputPath)
        isRunning = false
    }

    func stop() {
        process?.terminate()
        isRunning = false
    }

    private func parseJTL(at path: String) -> JMeterResult? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }

        let lines = content.components(separatedBy: "\n").dropFirst() // skip header
        var totalMs: Double = 0
        var successCount = 0
        var errorCount = 0
        var count = 0

        for line in lines where !line.isEmpty {
            let cols = line.components(separatedBy: ",")
            guard cols.count > 7 else { continue }
            let ms       = Double(cols[1]) ?? 0
            let success  = cols[7].trimmingCharacters(in: .whitespaces).lowercased() == "true"
            totalMs     += ms
            success ? (successCount += 1) : (errorCount += 1)
            count += 1
        }

        guard count > 0 else { return nil }

        return JMeterResult(
            successRate: Double(successCount) / Double(count) * 100,
            avgResponseMs: totalMs / Double(count),
            requestsPerSec: Double(count) / 60.0,
            errorRate: Double(errorCount) / Double(count) * 100
        )
    }
}
