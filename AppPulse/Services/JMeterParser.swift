import Foundation

class JMeterParser {
    func parse(at url: URL) throws -> [JMeterSample] {
        let raw = try String(contentsOf: url, encoding: .utf8)
        let firstLine = raw.prefix(while: { $0 != "\n" && $0 != "\r" })
        if firstLine.hasPrefix("<") {
            return try parseXML(data: Data(raw.utf8))
        } else {
            return try parseCSV(raw)
        }
    }

    // MARK: - CSV

    private func parseCSV(_ content: String) throws -> [JMeterSample] {
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard let header = lines.first else { throw ParserError.emptyFile }

        let cols = header.components(separatedBy: ",")
        guard let tsIdx     = cols.firstIndex(of: "timeStamp"),
              let elapsedIdx = cols.firstIndex(of: "elapsed"),
              let labelIdx   = cols.firstIndex(of: "label"),
              let rcIdx      = cols.firstIndex(of: "responseCode"),
              let successIdx = cols.firstIndex(of: "success"),
              let bytesIdx   = cols.firstIndex(of: "bytes")
        else { throw ParserError.missingColumns }

        return lines.dropFirst().compactMap { line -> JMeterSample? in
            let fields = line.components(separatedBy: ",")
            guard fields.count > max(tsIdx, elapsedIdx, labelIdx, rcIdx, successIdx, bytesIdx) else { return nil }
            let tsMs = Double(fields[tsIdx]) ?? 0
            let elapsedMs = Double(fields[elapsedIdx]) ?? 0
            return JMeterSample(
                label: fields[labelIdx],
                responseTime: elapsedMs / 1000,
                success: fields[successIdx].lowercased() == "true",
                responseCode: fields[rcIdx],
                bytes: Int(fields[bytesIdx]) ?? 0,
                timestamp: Date(timeIntervalSince1970: tsMs / 1000)
            )
        }
    }

    // MARK: - XML

    private func parseXML(data: Data) throws -> [JMeterSample] {
        let parser = JTLXMLParser(data: data)
        return try parser.parse()
    }

    enum ParserError: LocalizedError {
        case emptyFile, missingColumns
        var errorDescription: String? {
            switch self {
            case .emptyFile: return "The .jtl file is empty."
            case .missingColumns: return "CSV is missing required JMeter columns (timeStamp, elapsed, label, responseCode, success, bytes)."
            }
        }
    }
}

struct JMeterSample: Identifiable, Codable {
    var id: UUID = UUID()
    var label: String
    var responseTime: TimeInterval
    var success: Bool
    var responseCode: String
    var bytes: Int
    var timestamp: Date
}

struct JMeterRun: Identifiable, Codable {
    let id: UUID
    var name: String
    var importedAt: Date
    var samples: [JMeterSample]
    var notes: String = ""

    var passRate: Double {
        guard !samples.isEmpty else { return 0 }
        return Double(samples.filter(\.success).count) / Double(samples.count) * 100
    }

    var avgResponseTime: Double {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.responseTime).reduce(0, +) / Double(samples.count) * 1000
    }
}

private class JTLXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var samples: [JMeterSample] = []

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [JMeterSample] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }
        return samples
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String] = [:]) {
        guard elementName == "httpSample" || elementName == "sample" else { return }
        let ms = Double(attributes["t"] ?? "0") ?? 0
        let ts = Double(attributes["ts"] ?? "0") ?? 0
        let sample = JMeterSample(
            label: attributes["lb"] ?? "",
            responseTime: ms / 1000,
            success: attributes["s"] == "true",
            responseCode: attributes["rc"] ?? "",
            bytes: Int(attributes["by"] ?? "0") ?? 0,
            timestamp: Date(timeIntervalSince1970: ts / 1000)
        )
        samples.append(sample)
    }
}
