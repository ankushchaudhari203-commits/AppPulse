import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }

    private func send(title: String, body: String, id: String = UUID().uuidString) {
        guard notificationsEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    func notifyEndpointDown(_ endpoint: String) {
        guard UserDefaults.standard.bool(forKey: "notifyEndpointDown") else { return }
        send(title: "Endpoint Down", body: "\(endpoint) is not responding", id: "down-\(endpoint)")
    }

    func notifyEndpointRecovered(_ endpoint: String) {
        guard UserDefaults.standard.bool(forKey: "notifyEndpointRecovered") else { return }
        send(title: "Endpoint Recovered", body: "\(endpoint) is back online", id: "up-\(endpoint)")
    }

    func notifyGenerationComplete(suiteName: String) {
        guard UserDefaults.standard.bool(forKey: "notifyGenerationComplete") else { return }
        send(title: "Test Cases Ready", body: "\u{201C}\(suiteName)\u{201D} generated successfully")
    }

    func notifyLocustStarted() {
        guard UserDefaults.standard.bool(forKey: "notifyLocustEvents") else { return }
        send(title: "Load Test Started", body: "Locust is now running", id: "locust-start")
    }

    func notifyLocustStopped() {
        guard UserDefaults.standard.bool(forKey: "notifyLocustEvents") else { return }
        send(title: "Load Test Stopped", body: "Locust has finished", id: "locust-stop")
    }

    func notifyCIFileImported(_ filename: String) {
        guard UserDefaults.standard.bool(forKey: "notifyCIImport") else { return }
        send(title: "CI File Imported", body: "\(filename) was auto-imported from the watch folder")
    }

    func notifyTestRunComplete(name: String, passed: Int, total: Int) {
        guard UserDefaults.standard.bool(forKey: "notifyTestRuns") else { return }
        let rate = total > 0 ? Int(Double(passed) / Double(total) * 100) : 0
        let icon = rate >= 90 ? "✅" : rate >= 70 ? "⚠️" : "❌"
        send(title: "\(icon) Test Run Complete", body: "\(name): \(passed)/\(total) passed (\(rate)%)")
    }

    func notifyJMeterComplete(name: String, passRate: Double, samples: Int) {
        guard UserDefaults.standard.bool(forKey: "notifyTestRuns") else { return }
        let icon = passRate >= 95 ? "✅" : passRate >= 80 ? "⚠️" : "❌"
        send(title: "\(icon) JMeter Run Complete", body: "\(name): \(Int(passRate))% pass · \(samples) samples")
    }
}
