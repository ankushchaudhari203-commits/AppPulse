import Foundation

enum SlackNotifier {
    static func post(webhookURL: String, text: String) {
        guard !webhookURL.isEmpty, let url = URL(string: webhookURL) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])
        URLSession.shared.dataTask(with: request).resume()
    }

    static func postTestRun(webhookURL: String, name: String, passed: Int, total: Int, passRate: Double) {
        let e = passRate >= 90 ? ":white_check_mark:" : passRate >= 70 ? ":warning:" : ":x:"
        post(webhookURL: webhookURL,
             text: "\(e) *AppPulse · Functional Tests*\n*\(name)*: \(passed)/\(total) tests passed (`\(Int(passRate))%`)")
    }

    static func postJMeter(webhookURL: String, name: String, passRate: Double, samples: Int, avgRT: Double) {
        let e = passRate >= 95 ? ":white_check_mark:" : passRate >= 80 ? ":warning:" : ":x:"
        post(webhookURL: webhookURL,
             text: "\(e) *AppPulse · JMeter*\n*\(name)*: `\(Int(passRate))%` pass · \(samples) samples · `\(Int(avgRT)) ms` avg RT")
    }

    static func postAPIHealth(webhookURL: String, healthy: Int, total: Int) {
        let e = healthy == total ? ":white_check_mark:" : healthy > 0 ? ":warning:" : ":x:"
        post(webhookURL: webhookURL,
             text: "\(e) *AppPulse · API Health*\n\(healthy)/\(total) endpoints healthy")
    }
}
