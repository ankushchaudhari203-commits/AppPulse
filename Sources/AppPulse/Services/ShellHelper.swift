import Foundation

// Shared helper to run shell commands and capture output
@discardableResult
func shell(_ command: String) async -> String {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            let process = Process()
            process.launchPath = "/bin/zsh"
            process.arguments = ["-c", command]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError  = pipe

            process.launch()
            process.waitUntilExit()

            let data   = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            continuation.resume(returning: output)
        }
    }
}

// Convenience run for Process without output
extension Process {
    static func run(_ path: String, arguments: [String]) {
        let p = Process()
        p.launchPath = path
        p.arguments = arguments
        try? p.run()
    }
}
