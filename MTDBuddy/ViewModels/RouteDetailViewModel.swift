import Foundation

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published var vehicles: [MTDVehicle] = []
    @Published var stopTimes: [MTDStopTime] = []
    @Published var reroutes: [MTDReroute] = []
    @Published var vehiclesError: Error?

    private let route: MTDRoute
    private let service: MTDService
    private var lastLoadedTripId: String?
    private var refreshTask: Task<Void, Never>?

    init(route: MTDRoute, service: MTDService = MTDServiceV2()) {
        self.route = route
        self.service = service
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                await refreshVehicles()
                try? await Task.sleep(for: .seconds(15))
            }
        }
        Task { await loadReroutes() }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refreshVehicles() async {
        do {
            vehicles = try await service.getVehiclesByRoute(routeId: route.routeId)
            vehiclesError = nil
            if let tripId = vehicles.first?.trip.tripId, tripId != lastLoadedTripId {
                lastLoadedTripId = tripId
                stopTimes = try await service.getStopTimesByTrip(tripId: tripId)
            }
        } catch {
            vehiclesError = error
        }
    }

    func loadReroutes() async {
        reroutes = (try? await service.getReroutesByRoute(routeId: route.routeId)) ?? []
    }
}
