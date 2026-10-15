import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var todayPlan: TodayPlan?
    @Published var favoriteDepartures: [String: [MTDDeparture]] = [:]
    @Published var favoriteErrors: [String: Error] = [:]
    @Published var settings = UserSettings.load()

    private let service: MTDService
    private var refreshTask: Task<Void, Never>?

    init(service: MTDService = MTDServiceV2()) {
        self.service = service
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        settings = UserSettings.load()
        todayPlan = TodayPlan.load()

        await withTaskGroup(of: (String, Result<[MTDDeparture], Error>).self) { group in
            for stopId in settings.favoriteStopIds {
                group.addTask {
                    do {
                        let departures = try await self.service.getDeparturesByStop(stopId: stopId)
                        return (stopId, .success(departures))
                    } catch {
                        return (stopId, .failure(error))
                    }
                }
            }
            for await (stopId, result) in group {
                switch result {
                case .success(let departures):
                    favoriteDepartures[stopId] = Array(departures.prefix(3))
                    favoriteErrors[stopId] = nil
                case .failure(let error):
                    favoriteErrors[stopId] = error
                }
            }
        }
    }

    func toggleLiveActivity() {
        guard let todayPlan else { return }
        if LiveActivityManager.shared.isTracking {
            LiveActivityManager.shared.end()
        } else {
            LiveActivityManager.shared.start(plan: todayPlan)
        }
    }

    func status(for departure: MTDDeparture, stopId: String) -> BoardStatus {
        BoardStatus(
            minutesUntilDeparture: departure.expected.minutesFromNow,
            walkMinutes: settings.walkMinutes(toStop: stopId)
        )
    }
}
