import Foundation
import Combine

@MainActor
final class XcodeBuildRunner: ObservableObject {
    @Published var isRunning   = false
    @Published var outputLines: [String] = []
    @Published var phase       = ""

    private var process: Process?

    func run(projectPath: String, scheme: String, destination: String) async throws -> URL {
        guard !projectPath.isEmpty, !scheme.isEmpty else { throw RunnerError.notConfigured }

        let resultURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(scheme)_\(Int(Date().timeIntervalSince1970)).xcresult")
        try? FileManager.default.removeItem(at: resultURL)

        isRunning   = true
        outputLines = []
        phase       = "Building…"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")

        var args = ["test", "-scheme", scheme,
                    "-resultBundlePath", resultURL.path,
                    "-destination", destination.isEmpty ? "platform=macOS" : destination,
                    "-allowProvisioningUpdates"]
        if projectPath.hasSuffix(".xcworkspace") {
            args += ["-workspace", projectPath]
        } else {
            args += ["-project", projectPath]
        }
        proc.arguments = args

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError  = pipe
        self.process = proc

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.outputLines.append(contentsOf: lines)
                for line in lines {
                    if line.contains("BUILD SUCCEEDED") { self.phase = "Running tests…" }
                    if line.contains("TEST SUCCEEDED")  { self.phase = "Completed ✓" }
                    if line.contains("TEST FAILED")     { self.phase = "Completed (with failures)" }
                }
            }
        }

        do {
            try proc.run()
        } catch {
            isRunning = false
            throw RunnerError.launchFailed(error.localizedDescription)
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            proc.terminationHandler = { _ in cont.resume() }
        }

        pipe.fileHandleForReading.readabilityHandler = nil
        isRunning = false

        guard FileManager.default.fileExists(atPath: resultURL.path) else {
            throw RunnerError.noBundle
        }
        return resultURL
    }

    func cancel() {
        process?.interrupt()
        process  = nil
        isRunning = false
        phase     = "Cancelled"
    }

    enum RunnerError: LocalizedError {
        case notConfigured, noBundle
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:       return "Configure your Xcode project path and scheme in Settings → Tools."
            case .noBundle:            return "xcodebuild ran but no .xcresult bundle was created. Check that the scheme has a test target and the destination is correct."
            case .launchFailed(let e): return "Failed to launch xcodebuild: \(e)"
            }
        }
    }
}
