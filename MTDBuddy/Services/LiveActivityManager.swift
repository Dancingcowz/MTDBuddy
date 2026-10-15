import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<BusActivityAttributes>?

    var isTracking: Bool { currentActivity != nil }

    func start(plan: TodayPlan) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end()
        let attributes = BusActivityAttributes(classTitle: plan.classTitle)
        let state = contentState(for: plan)
        currentActivity = try? Activity.request(
            attributes: attributes,
            content: .init(state: state, staleDate: plan.arriveTime)
        )
    }

    /// Called after every re-plan so an already-running activity reflects live refinements.
    func update(plan: TodayPlan) {
        guard let currentActivity else { return }
        let state = contentState(for: plan)
        Task { await currentActivity.update(.init(state: state, staleDate: plan.arriveTime)) }
    }

    func end() {
        guard let activity = currentActivity else { return }
        Task { await activity.end(nil, dismissalPolicy: .default) }
        currentActivity = nil
    }

    private func contentState(for plan: TodayPlan) -> BusActivityAttributes.ContentState {
        .init(
            leaveTime: plan.leaveTime, boardTime: plan.boardTime,
            routeShortName: plan.routeShortName, boardingStopName: plan.boardingStopName,
            isLive: plan.isLive
        )
    }
}
