import Foundation

/// Single shared set of services so the SwiftUI app, the BGAppRefreshTask, and the App
/// Intents (which may run without the UI ever appearing) all plan against the same state.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let locationManager = LocationManager()
    let calendarManager = GoogleCalendarManager()
    let notificationManager = NotificationManager.shared
    let mtdService: MTDService = MTDServiceV2()

    lazy var busAlertPlanner = BusAlertPlanner(
        calendar: calendarManager, service: mtdService, notifications: notificationManager
    )

    private init() {}
}
