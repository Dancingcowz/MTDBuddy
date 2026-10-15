import SwiftUI
import MapKit

struct StopDetailView: View {
    let stop: MTDStop
    @StateObject private var viewModel: StopDetailViewModel

    init(stop: MTDStop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: StopDetailViewModel(stop: stop))
    }

    private var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.centerLat, longitude: stop.centerLon)
    }

    var body: some View {
        List {
            Section {
                Map(initialPosition: .region(MKCoordinateRegion(center: center, latitudinalMeters: 300, longitudinalMeters: 300))) {
                    ForEach(stop.stopPoints, id: \.stopId) { point in
                        Marker(point.stopName, coordinate: CLLocationCoordinate2D(latitude: point.stopLat, longitude: point.stopLon))
                    }
                }
                .frame(height: 180)
                .listRowInsets(EdgeInsets())

                HStack {
                    Button {
                        openInMaps()
                    } label: {
                        Label("Open in Maps", systemImage: "map")
                    }
                    Spacer()
                    Stepper("Walk: \(viewModel.walkMinutes) min", value: Binding(
                        get: { viewModel.walkMinutes },
                        set: { viewModel.setWalkMinutes($0) }
                    ), in: 1...30)
                    .fixedSize()
                }
            }

            if !legendRoutes.isEmpty {
                Section("Routes at this stop") {
                    ForEach(legendRoutes, id: \.routeId) { route in
                        HStack {
                            RouteBadge(shortName: route.routeShortName, colorHex: route.routeColor, textColorHex: route.routeTextColor)
                            Text(route.routeLongName)
                            Spacer()
                        }
                    }
                }
            }

            Section("Next 60 minutes") {
                if let error = viewModel.error, viewModel.departures.isEmpty {
                    ErrorStateView(error: error) { Task { await viewModel.refresh() } }
                } else if viewModel.departuresNextHour.isEmpty {
                    Text(viewModel.isLoading ? "Loading…" : "No departures in the next hour")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.departuresNextHour) { departure in
                        DepartureRow(
                            departure: departure,
                            status: BoardStatus(minutesUntilDeparture: departure.expected.minutesFromNow, walkMinutes: viewModel.walkMinutes)
                        )
                    }
                }
            }
        }
        .navigationTitle(stop.stopName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleFavorite()
                } label: {
                    Image(systemName: viewModel.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(IlliniColor.orange)
                }
            }
        }
        .task {
            await viewModel.refresh()
            viewModel.startAutoRefresh()
        }
        .onDisappear { viewModel.stopAutoRefresh() }
        .refreshable { await viewModel.refresh() }
    }

    private var legendRoutes: [MTDRoute] {
        var seen = Set<String>()
        var result: [MTDRoute] = []
        for departure in viewModel.departures {
            if !seen.contains(departure.route.routeId) {
                seen.insert(departure.route.routeId)
                result.append(departure.route)
            }
        }
        return result
    }

    private func openInMaps() {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: center))
        item.name = stop.stopName
        item.openInMaps()
    }
}
