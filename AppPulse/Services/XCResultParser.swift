import Foundation

class XCResultParser {
    func parse(at url: URL) throws -> TestRun {
        _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        let json = try runTool(path: url.path)
        guard let data = json.data(using: .utf8) else { throw ParseError.invalidData }
        var run = try decodeRun(data, name: url.deletingPathExtension().lastPathComponent)

        // Second pass: fetch individual test cases via testsRef id
        if let record = try? JSONDecoder().decode(XCResultRecord.self, from: data),
           let refId = record.actions?.values.compactMap({ $0.actionResult?.testsRef?.id?.value }).first {
            let casesJson = try runTool(path: url.path, id: refId)
            if let casesData = casesJson.data(using: .utf8) {
                run.testCases = decodeTestCases(casesData)
            }
        }
        return run
    }

    // MARK: - Run summary (Codable)

    private func decodeRun(_ data: Data, name: String) throws -> TestRun {
        let record = try JSONDecoder().decode(XCResultRecord.self, from: data)
        let metrics = record.metrics
        let total   = metrics?.testsCount?.intValue ?? 0
        let failed  = metrics?.testsFailedCount?.intValue ?? 0
        let skipped = metrics?.testsSkippedCount?.intValue ?? 0
        let passed  = max(0, total - failed - skipped)

        var duration: TimeInterval = 0
        var date = Date()
        if let action = record.actions?.values.first {
            let fmt = ISO8601DateFormatter()
            if let startStr = action.startedTime?.value,
               let endStr   = action.endedTime?.value,
               let start    = fmt.date(from: startStr),
               let end      = fmt.date(from: endStr) {
                duration = end.timeIntervalSince(start)
                date = start
            }
        }
        return TestRun(
            id: UUID(), name: name, date: date,
            status: failed > 0 ? .failed : .passed,
            duration: duration,
            totalTests: total, passedTests: passed,
            failedTests: failed, skippedTests: skipped
        )
    }

    // MARK: - Individual test cases (JSONSerialization — avoids recursive Codable issues)

    private func decodeTestCases(_ data: Data) -> [TestCase] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        var cases: [TestCase] = []
        let summaries = values(root, key: "summaries")
        for summary in summaries {
            for testable in values(summary, key: "testableSummaries") {
                for group in values(testable, key: "tests") {
                    flattenItem(group, into: &cases)
                }
            }
        }
        return cases
    }

    private func flattenItem(_ item: [String: Any], into cases: inout [TestCase]) {
        if let statusStr = stringValue(item, key: "testStatus") {
            let rawName  = stringValue(item, key: "name")
                        ?? stringValue(item, key: "identifier")
                        ?? "Unknown"
            let name     = rawName.components(separatedBy: "/").last ?? rawName
            let duration = Double(stringValue(item, key: "duration") ?? "0") ?? 0
            let status: TestCase.TestCaseStatus
            switch statusStr {
            case "Success": status = .passed
            case "Failure": status = .failed
            default:        status = .skipped
            }
            cases.append(TestCase(id: UUID(), name: name, status: status, duration: duration))
        } else {
            for sub in values(item, key: "subtests") {
                flattenItem(sub, into: &cases)
            }
        }
    }

    // Helpers to navigate the xcresult "_values" / "_value" structure
    private func values(_ dict: [String: Any], key: String) -> [[String: Any]] {
        (dict[key] as? [String: Any])?["_values"] as? [[String: Any]] ?? []
    }
    private func stringValue(_ dict: [String: Any], key: String) -> String? {
        (dict[key] as? [String: Any])?["_value"] as? String
    }

    // MARK: - xcresulttool runner

    private func runTool(path: String, id: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        var args = ["xcresulttool", "get", "object", "--legacy", "--format", "json", "--path", path]
        if let id { args += ["--id", id] }
        process.arguments = args
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError  = err
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown"
            throw ParseError.commandFailed(msg)
        }
        return String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    enum ParseError: LocalizedError {
        case invalidData
        case commandFailed(String)
        var errorDescription: String? {
            switch self {
            case .invalidData:          return "Failed to decode xcresult data"
            case .commandFailed(let m): return "xcresulttool failed: \(m)"
            }
        }
    }
}

// MARK: - Top-level Codable models

private struct XCResultRecord: Codable {
    let metrics: XCResultMetrics?
    let actions: XCResultArray<XCResultAction>?
}
private struct XCResultMetrics: Codable {
    let testsCount: XCResultValue?
    let testsFailedCount: XCResultValue?
    let testsSkippedCount: XCResultValue?
}
private struct XCResultAction: Codable {
    let startedTime: XCResultValue?
    let endedTime: XCResultValue?
    let actionResult: XCResultActionResult?
}
private struct XCResultActionResult: Codable {
    let testsRef: XCResultRef?
}
private struct XCResultRef: Codable {
    let id: XCResultValue?
}
private struct XCResultValue: Codable {
    let value: String?
    enum CodingKeys: String, CodingKey { case value = "_value" }
    var intValue: Int { value.flatMap(Int.init) ?? 0 }
}
private struct XCResultArray<T: Codable>: Codable {
    let values: [T]
    enum CodingKeys: String, CodingKey { case values = "_values" }
}
