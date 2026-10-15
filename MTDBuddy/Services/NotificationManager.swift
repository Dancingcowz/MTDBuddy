import UserNotifications
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    /// Set when the user taps a notification; MTDBuddyApp observes this to open that stop.
    @Published var deepLinkStopId: String?

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    enum AlertKind: String {
        case headsUp, leaveNow, fallback
    }

    func scheduleAlert(classKey: String, kind: AlertKind, fireDate: Date, title: String, body: String, boardingStopId: String?) {
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let boardingStopId {
            content.userInfo = ["stopId": boardingStopId]
        }
        let interval = fireDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 1), repeats: false)
        let identifier = identifier(classKey: classKey, kind: kind)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAlerts(classKey: String) {
        let ids = [AlertKind.headsUp, .leaveNow, .fallback].map { identifier(classKey: classKey, kind: $0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// A one-off "service alert" notification for a newly detected reroute affecting a route
    /// the user actually relies on (see BusAlertPlanner.checkServiceAlerts) — unlike
    /// scheduleAlert, this doesn't replace a prior day's identifier since each reroute is its
    /// own event, not a daily recurring slot.
    func sendServiceAlert(title: String, body: String, boardingStopId: String?) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let boardingStopId {
            content.userInfo = ["stopId": boardingStopId]
        }
        let request = UNNotificationRequest(
            identifier: "service-alert-\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(request)
    }

    func sendTestNotification(boardingStopId: String?) {
        let content = UNMutableNotificationContent()
        content.title = "MTD Buddy test"
        content.body = "If you see this, notifications are working."
        content.sound = .default
        if let boardingStopId {
            content.userInfo = ["stopId": boardingStopId]
        }
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false))
        center.add(request)
    }

    private func identifier(classKey: String, kind: AlertKind) -> String {
        let day = DateFormatter.mtdDayStamp.string(from: Date())
        return "mtd-\(kind.rawValue)-\(classKey)-\(day)"
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let stopId = response.notification.request.content.userInfo["stopId"] as? String else { return }
        await MainActor.run { self.deepLinkStopId = stopId }
    }
}

extension DateFormatter {
    static let mtdDayStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
