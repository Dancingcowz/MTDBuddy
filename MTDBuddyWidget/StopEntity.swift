import AppIntents

struct StopEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Bus Stop"
    static var defaultQuery = StopEntityQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

/// Backs the widget's configuration intent. Hits the network directly (via the cached
/// MTDServiceV2) rather than relying on the App Group, so the widget keeps working even when
/// the entitlement doesn't survive an AltStore re-sign.
struct StopEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StopEntity] {
        let stops = try await MTDServiceV2().getStops()
        return stops.filter { identifiers.contains($0.stopId) }.map { StopEntity(id: $0.stopId, name: $0.stopName) }
    }

    func suggestedEntities() async throws -> [StopEntity] {
        let stops = try await MTDServiceV2().getStops()
        return stops.prefix(30).map { StopEntity(id: $0.stopId, name: $0.stopName) }
    }
}

struct MTDWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "MTD Buddy Stop"
    static var description = IntentDescription("Pick a stop to show, or leave blank to use your main favorite stop.")

    @Parameter(title: "Stop")
    var stop: StopEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show departures for \(\.$stop)")
    }
}
