import Foundation
import Combine

@MainActor
final class JMeterCLIRunner: ObservableObject {
    @Published var isRunning   = false
    @Published var outputLines: [String] = []
    @Published var phase       = ""

    private var process: Process?

    // Builds HTTPHeaderManager XML block from auth params
    private func headerManagerXML(authType: String, authValue: String, authHeader: String) -> String {
        var headers: [(String, String)] = []
        switch authType {
        case "Bearer Token":
            headers = [("Authorization", "Bearer \(authValue)")]
        case "API Key":
            headers = [(authHeader.isEmpty ? "X-API-Key" : authHeader, authValue)]
        case "Basic Auth":
            let encoded = Data(authValue.utf8).base64EncodedString()
            headers = [("Authorization", "Basic \(encoded)")]
        case "Custom Header":
            if !authHeader.isEmpty && !authValue.isEmpty {
                headers = [(authHeader, authValue)]
            }
        default:
            return ""
        }
        guard !headers.isEmpty else { return "" }
        let props = headers.map { name, value in
            """
                    <elementProp name="" elementType="Header">
                      <stringProp name="Header.name">\(name)</stringProp>
                      <stringProp name="Header.value">\(value)</stringProp>
                    </elementProp>
            """
        }.joined(separator: "\n")
        return """
                <HeaderManager guiclass="HeaderPanel" testclass="HeaderManager" testname="HTTP Header Manager">
                  <collectionProp name="HeaderManager.headers">
        \(props)
                  </collectionProp>
                </HeaderManager>
                <hashTree/>
        """
    }

    func generateJMX(urlString: String, method: String, users: Int, rampUp: Int, duration: Int,
                     authType: String = "None", authValue: String = "", authHeader: String = "") throws -> URL {
        guard let url = URL(string: urlString),
              let host = url.host else {
            throw RunnerError.invalidURL
        }
        let scheme   = url.scheme ?? "https"
        let port     = url.port ?? (scheme == "https" ? 443 : 80)
        let path     = url.path.isEmpty ? "/" : url.path

        let jmx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
          <hashTree>
            <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="AppPulse Quick Test">
              <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
                <collectionProp name="Arguments.arguments"/>
              </elementProp>
              <boolProp name="TestPlan.functional_mode">false</boolProp>
              <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
            </TestPlan>
            <hashTree>
              <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Thread Group">
                <intProp name="ThreadGroup.num_threads">\(users)</intProp>
                <intProp name="ThreadGroup.ramp_time">\(rampUp)</intProp>
                <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
                <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
                <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
                  <boolProp name="LoopController.continue_forever">false</boolProp>
                  <intProp name="LoopController.loops">-1</intProp>
                </elementProp>
                <longProp name="ThreadGroup.duration">\(duration)</longProp>
                <longProp name="ThreadGroup.delay">0</longProp>
                <boolProp name="ThreadGroup.scheduler">true</boolProp>
              </ThreadGroup>
              <hashTree>
                <HTTPSamplerProxy guiclass="HttpTestSampleGui" testclass="HTTPSamplerProxy" testname="HTTP Request">
                  <stringProp name="HTTPSampler.domain">\(host)</stringProp>
                  <intProp name="HTTPSampler.port">\(port)</intProp>
                  <stringProp name="HTTPSampler.protocol">\(scheme)</stringProp>
                  <stringProp name="HTTPSampler.path">\(path)</stringProp>
                  <stringProp name="HTTPSampler.method">\(method)</stringProp>
                  <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
                  <boolProp name="HTTPSampler.auto_redirects">false</boolProp>
                  <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
                </HTTPSamplerProxy>
                <hashTree/>
                \(headerManagerXML(authType: authType, authValue: authValue, authHeader: authHeader))
              </hashTree>
            </hashTree>
          </hashTree>
        </jmeterTestPlan>
        """

        let jmxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppPulse_quick_\(Int(Date().timeIntervalSince1970)).jmx")
        try jmx.write(to: jmxURL, atomically: true, encoding: .utf8)
        return jmxURL
    }

    func generateWebSocketJMX(urlString: String, message: String, users: Int, rampUp: Int, duration: Int,
                              authType: String = "None", authValue: String = "", authHeader: String = "") throws -> URL {
        guard let url = URL(string: urlString),
              let host = url.host else {
            throw RunnerError.invalidURL
        }
        let tls    = url.scheme == "wss"
        let port   = url.port ?? (tls ? 443 : 80)
        let path   = url.path.isEmpty ? "/" : url.path

        let jmx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
          <hashTree>
            <TestPlan guiclass="TestPlanGui" testclass="TestPlan" testname="AppPulse WebSocket Quick Test">
              <elementProp name="TestPlan.user_defined_variables" elementType="Arguments">
                <collectionProp name="Arguments.arguments"/>
              </elementProp>
              <boolProp name="TestPlan.functional_mode">false</boolProp>
              <boolProp name="TestPlan.serialize_threadgroups">false</boolProp>
            </TestPlan>
            <hashTree>
              <ThreadGroup guiclass="ThreadGroupGui" testclass="ThreadGroup" testname="Thread Group">
                <intProp name="ThreadGroup.num_threads">\(users)</intProp>
                <intProp name="ThreadGroup.ramp_time">\(rampUp)</intProp>
                <boolProp name="ThreadGroup.same_user_on_next_iteration">true</boolProp>
                <stringProp name="ThreadGroup.on_sample_error">continue</stringProp>
                <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
                  <boolProp name="LoopController.continue_forever">false</boolProp>
                  <intProp name="LoopController.loops">-1</intProp>
                </elementProp>
                <longProp name="ThreadGroup.duration">\(duration)</longProp>
                <longProp name="ThreadGroup.delay">0</longProp>
                <boolProp name="ThreadGroup.scheduler">true</boolProp>
              </ThreadGroup>
              <hashTree>
                <eu.luminis.jmeter.wssampler.RequestResponseWebSocketSampler
                  guiclass="eu.luminis.jmeter.wssampler.RequestResponseWebSocketSamplerUI"
                  testclass="eu.luminis.jmeter.wssampler.RequestResponseWebSocketSampler"
                  testname="WebSocket Request-Response">
                  <stringProp name="server">\(host)</stringProp>
                  <stringProp name="port">\(port)</stringProp>
                  <stringProp name="path">\(path)</stringProp>
                  <boolProp name="tls">\(tls)</boolProp>
                  <stringProp name="requestData">\(message)</stringProp>
                  <intProp name="readTimeout">6000</intProp>
                  <intProp name="connectTimeout">6000</intProp>
                </eu.luminis.jmeter.wssampler.RequestResponseWebSocketSampler>
                <hashTree/>
                \(headerManagerXML(authType: authType, authValue: authValue, authHeader: authHeader))
              </hashTree>
            </hashTree>
          </hashTree>
        </jmeterTestPlan>
        """

        let jmxURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppPulse_ws_quick_\(Int(Date().timeIntervalSince1970)).jmx")
        try jmx.write(to: jmxURL, atomically: true, encoding: .utf8)
        return jmxURL
    }

    func run(jmxPath: String, jmeterExecutable: String) async throws -> URL {
        guard FileManager.default.isExecutableFile(atPath: jmeterExecutable) else {
            throw RunnerError.jmeterNotFound
        }

        let jtlURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppPulse_jmeter_\(Int(Date().timeIntervalSince1970)).jtl")
        try? FileManager.default.removeItem(at: jtlURL)

        isRunning   = true
        outputLines = []
        phase       = "Running JMeter test…"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: jmeterExecutable)
        proc.arguments     = ["-n", "-t", jmxPath, "-l", jtlURL.path]

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
            Task { @MainActor [weak self] in self?.outputLines.append(contentsOf: lines) }
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
        phase     = ""

        guard FileManager.default.fileExists(atPath: jtlURL.path) else {
            throw RunnerError.noOutput
        }
        return jtlURL
    }

    func cancel() {
        process?.interrupt()
        process   = nil
        isRunning = false
        phase     = ""
    }

    enum RunnerError: LocalizedError {
        case jmeterNotFound, noOutput, invalidURL
        case launchFailed(String)

        var errorDescription: String? {
            switch self {
            case .jmeterNotFound:      return "JMeter executable not found. Check the path in Settings → Tools."
            case .noOutput:            return "JMeter ran but no .jtl results file was created."
            case .invalidURL:          return "Invalid URL. Please enter a valid http:// or https:// URL."
            case .launchFailed(let e): return "Failed to launch JMeter: \(e)"
            }
        }
    }
}
