import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func sendRecoveryAlert(score: Int) {
        let content = UNMutableNotificationContent()
        content.title = "WHOOP Recovery"

        let label = Constants.Recovery.label(for: score)
        content.body = "Your recovery is \(score)% (\(label))"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "recovery-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
