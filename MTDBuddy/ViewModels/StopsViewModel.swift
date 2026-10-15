import Foundation
import CoreLocation

@MainActor
final class StopsViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var sortByNearest = false

    func filteredStops(from stops: [MTDStop], userLocation: CLLocation?) -> [MTDStop] {
        var result = stops
        if !searchText.isEmpty {
            result = result.filter { $0.stopName.localizedCaseInsensitiveContains(searchText) }
        }
        if sortByNearest, let userLocation {
            result = result.sorted {
                let d0 = CLLocation(latitude: $0.centerLat, longitude: $0.centerLon).distance(from: userLocation)
                let d1 = CLLocation(latitude: $1.centerLat, longitude: $1.centerLon).distance(from: userLocation)
                return d0 < d1
            }
        } else {
            result = result.sorted { $0.stopName < $1.stopName }
        }
        return result
    }

    /// A–Z section groups, keyed by first letter — skipped when sorting by distance.
    func sections(from stops: [MTDStop]) -> [(letter: String, stops: [MTDStop])] {
        let grouped = Dictionary(grouping: stops) { stop -> String in
            String(stop.stopName.first ?? "#").uppercased()
        }
        return grouped.keys.sorted().map { ($0, grouped[$0]!.sorted { $0.stopName < $1.stopName }) }
    }
}
