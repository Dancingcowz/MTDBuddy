import SwiftUI

@main
struct MTDBuddyApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var locationManager = AppEnvironment.shared.locationManager
    @StateObject private var calendarManager = AppEnvironment.shared.calendarManager
    @StateObject private var notificationManager = AppEnvironment.shared.notificationManager
    @AppStorage("mtd_has_onboarded") private var hasOnboarded = false

    init() {
        BGTaskManager.register { AppEnvironment.shared.busAlertPlanner }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasOnboarded {
                    RootTabView()
                } else {
                    OnboardingView(isComplete: $hasOnboarded)
                }
            }
            .environmentObject(locationManager)
            .environmentObject(calendarManager)
            .environmentObject(notificationManager)
            .task {
                await AppEnvironment.shared.busAlertPlanner.planToday()
                BGTaskManager.scheduleNext()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await AppEnvironment.shared.busAlertPlanner.planToday() }
                } else if newPhase == .background {
                    BGTaskManager.scheduleNext()
                }
            }
        }
    }
}
