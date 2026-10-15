import BackgroundTasks
import Foundation

enum BGTaskManager {
    static let refreshIdentifier = "com.rexlan.mtdbuddy.refresh"

    static func register(planner: @escaping () -> BusAlertPlanner) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask, planner: planner())
        }
    }

    static func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask, planner: BusAlertPlanner) {
        scheduleNext() // always queue the next one first, per Apple's guidance

        let work = Task {
            await planner.planToday()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
}
