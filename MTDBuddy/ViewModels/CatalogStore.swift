import Foundation

/// Shared, app-wide cache of routes and stops (the two endpoints MTD asks clients to cache).
/// Loaded once and reused by every tab instead of each screen hitting the network separately.
@MainActor
final class CatalogStore: ObservableObject {
    @Published var stops: [MTDStop] = []
    @Published var routes: [MTDRoute] = []
    @Published var routesById: [String: MTDRoute] = [:]
    @Published var stopsById: [String: MTDStop] = [:]
    @Published var loadError: Error?
    @Published var isLoading = false

    private let service: MTDService

    init(service: MTDService) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard stops.isEmpty || routes.isEmpty else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        loadError = nil
        do {
            async let routesTask = service.getRoutes()
            async let stopsTask = service.getStops()
            let (fetchedRoutes, fetchedStops) = try await (routesTask, stopsTask)
            routes = fetchedRoutes.sorted { $0.routeLongName < $1.routeLongName }
            stops = fetchedStops.sorted { $0.stopName < $1.stopName }
            routesById = Dictionary(uniqueKeysWithValues: fetchedRoutes.map { ($0.routeId, $0) })
            stopsById = Dictionary(uniqueKeysWithValues: fetchedStops.map { ($0.stopId, $0) })
        } catch {
            loadError = error
        }
        isLoading = false
    }

    func stopName(_ stopId: String) -> String {
        stopsById[stopId]?.stopName ?? stopId
    }

    /// MTD's base weekday route_ids are riddled with ALT/EVENING/SATURDAY/SUNDAY/LATE NIGHT/
    /// HOPPER variants of the same ~19 colors (90 total route entries as of 2026-10-14) — too
    /// many to browse comfortably. This set isn't guessed: Illini, Silver, Green, Gold, Yellow,
    /// and Teal are named by the University of Illinois's own Facilities & Services site as the
    /// high-frequency (10-minute) "box pattern" routes dedicated to campus; Red is added per a
    /// Daily Illini rundown of the main campus routes. Grey, Brown, and Lavender round the list
    /// out to ~10 — well-known routes serving major off-campus areas (Savoy, north Champaign,
    /// north Urbana) but not part of either source's "high-frequency" list, so they're included
    /// for coverage, not because they're confirmed equally popular.
    static let popularRouteIds: Set<String> = [
        "ILLINI", "SILVER", "GREEN", "GOLD", "YELLOW", "TEAL", "RED", "GREY", "BROWN", "LAVENDER"
    ]

    var popularRoutes: [MTDRoute] {
        routes.filter { Self.popularRouteIds.contains($0.routeId) }
    }
}
