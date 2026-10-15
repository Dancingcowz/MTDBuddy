import Foundation

@MainActor
final class StopDetailViewModel: ObservableObject {
    @Published var departures: [MTDDeparture] = []
    @Published var error: Error?
    @Published var isLoading = false
    @Published var settings = UserSettings.load()

    private let stop: MTDStop
    private let service: MTDService
    private var refreshTask: Task<Void, Never>?

    init(stop: MTDStop, service: MTDService = MTDServiceV2()) {
        self.stop = stop
        self.service = service
    }

    var isFavorite: Bool { settings.favoriteStopIds.contains(stop.stopId) }

    var walkMinutes: Int {
        settings.walkMinutesByStopId[stop.stopId] ?? settings.homeWalkMinutes
    }

    /// Departures over the next 60 minutes, per spec.
    var departuresNextHour: [MTDDeparture] {
        let cutoff = Date().addingTimeInterval(60 * 60)
        return departures.filter { $0.expected <= cutoff }
    }

    func toggleFavorite() {
        settings = UserSettings.load()
        if isFavorite {
            settings.favoriteStopIds.removeAll { $0 == stop.stopId }
        } else {
            settings.favoriteStopIds.append(stop.stopId)
            if settings.mainFavoriteStopId == nil { settings.mainFavoriteStopId = stop.stopId }
        }
        settings.save()
    }

    func setWalkMinutes(_ minutes: Int) {
        settings = UserSettings.load()
        settings.walkMinutesByStopId[stop.stopId] = minutes
        settings.save()
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
        isLoading = true
        do {
            departures = try await service.getDeparturesByStop(stopId: stop.stopId)
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
