import AppIntents

struct PlanBusAlertsIntent: AppIntent {
    static var title: LocalizedStringResource = "Plan Today's Bus Alerts"
    static var description = IntentDescription("Re-plans MTD Buddy's bus alerts for today's remaining Bus classes.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppEnvironment.shared.busAlertPlanner.planToday()
        return .result()
    }
}

struct NextBusIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Bus"
    static var description = IntentDescription("Says when to leave for your next Bus class.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let plan = TodayPlan.load(), plan.leaveTime > Date() else {
            return .result(dialog: "You don't have a bus planned right now.")
        }
        let minutes = max(0, Int(plan.leaveTime.timeIntervalSinceNow / 60))
        if minutes <= 0 {
            return .result(dialog: "Leave now for \(plan.classTitle). Board at \(plan.boardingStopName).")
        }
        return .result(dialog: "Leave in \(minutes) minutes for \(plan.classTitle). Board at \(plan.boardingStopName).")
    }
}

struct MTDBuddyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PlanBusAlertsIntent(),
            phrases: ["Plan my bus alerts in \(.applicationName)"],
            shortTitle: "Plan Bus Alerts",
            systemImageName: "bus"
        )
        AppShortcut(
            intent: NextBusIntent(),
            phrases: ["When's my next bus in \(.applicationName)", "Next bus in \(.applicationName)"],
            shortTitle: "Next Bus",
            systemImageName: "clock"
        )
    }
}
