import SwiftUI
import MapKit

enum PlaceSearchError: Error, LocalizedError {
    case couldNotResolve
    var errorDescription: String? { "Couldn't find a location for that place. Try a more specific search." }
}

/// "Enter a location, find the closest stop" — Google-Maps-style place search that resolves to
/// a coordinate, then asks MTD's own GetStopsByLatLon (same endpoint "Nearest to me" uses) for
/// stops sorted by distance from that point, not the device's current location.
struct PlaceSearchStopsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchCompleter = LocalSearchCompleter()
    @State private var resolvedPlaceName: String?
    @State private var nearbyStops: [MTDStop] = []
    @State private var isResolving = false
    @State private var error: Error?

    private let service: MTDService = AppEnvironment.shared.mtdService

    var body: some View {
        NavigationStack {
            Group {
                if let resolvedPlaceName {
                    resultsList(placeName: resolvedPlaceName)
                } else {
                    suggestionsList
                }
            }
            .navigationTitle("Find Stops Near a Place")
            .searchable(text: $searchCompleter.query, prompt: "Address, building, or place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if resolvedPlaceName != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Search") {
                            resolvedPlaceName = nil
                            nearbyStops = []
                        }
                    }
                }
            }
        }
    }

    private var suggestionsList: some View {
        // Always a List (never swapped for a bare ContentUnavailableView) so `.searchable`'s
        // field placement/behavior stays consistent, with `.allowsHitTesting(false)` on the
        // placeholder overlay so it can never intercept taps meant for that field underneath it.
        List(searchCompleter.results, id: \.self) { completion in
            Button {
                Task { await resolve(completion) }
            } label: {
                VStack(alignment: .leading) {
                    Text(completion.title).foregroundStyle(.primary)
                    if !completion.subtitle.isEmpty {
                        Text(completion.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .overlay {
            if searchCompleter.query.isEmpty {
                ContentUnavailableView("Search for a Place", systemImage: "mappin.and.ellipse", description: Text("Try an address, building name, or landmark."))
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private func resultsList(placeName: String) -> some View {
        if isResolving {
            LoadingStateView()
        } else if let error {
            ErrorStateView(error: error) { resolvedPlaceName = nil }
        } else {
            List {
                Section("Nearest to \"\(placeName)\"") {
                    ForEach(nearbyStops) { stop in
                        NavigationLink(value: stop) {
                            VStack(alignment: .leading) {
                                Text(stop.stopName)
                                if let distance = stop.distance {
                                    Text(Self.formattedDistance(meters: distance))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationDestination(for: MTDStop.self) { StopDetailView(stop: $0) }
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) async {
        isResolving = true
        resolvedPlaceName = completion.title
        guard let coordinate = await searchCompleter.resolve(completion) else {
            error = PlaceSearchError.couldNotResolve
            isResolving = false
            return
        }
        do {
            nearbyStops = try await service.getStopsByLatLon(lat: coordinate.latitude, lon: coordinate.longitude)
            error = nil
        } catch {
            self.error = error
        }
        isResolving = false
    }

    private static func formattedDistance(meters: Double) -> String {
        let feet = meters * 3.28084
        if feet < 1000 { return "\(Int(feet)) ft away" }
        return String(format: "%.1f mi away", feet / 5280)
    }
}
