import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

final class MirrorNotificationService {
    func requestAuthorization() async {
        #if canImport(UserNotifications)
        do {
            try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            print("Notification authorization failed: \(error)")
        }
        #endif
    }

    func notify(alert: AlertInfo) async {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.message
        content.sound = .default
        let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Notification delivery failed: \(error)")
        }
        #else
        print("[\(alert.severity.uppercased())] \(alert.title): \(alert.message)")
        #endif
    }
}
