import SwiftUI
import MapKit

struct RouteDetailView: View {
    let route: MTDRoute
    @EnvironmentObject private var catalog: CatalogStore
    @StateObject private var viewModel: RouteDetailViewModel
    @State private var cameraPosition: MapCameraPosition = .region(Self.championUrbanaRegion)

    /// Champaign-Urbana, used until real stop/vehicle coordinates are in so the map doesn't
    /// default to MapKit's zoomed-out world view.
    private static let championUrbanaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.1092, longitude: -88.2272),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    init(route: MTDRoute) {
        self.route = route
        _viewModel = StateObject(wrappedValue: RouteDetailViewModel(route: route))
    }

    var body: some View {
        List {
            Section {
                Map(position: $cameraPosition) {
                    ForEach(viewModel.stopTimes) { stopTime in
                        Marker(stopTime.stopPoint.stopName, coordinate: .init(latitude: stopTime.stopPoint.stopLat, longitude: stopTime.stopPoint.stopLon))
                            .tint(.secondary)
                    }
                    ForEach(viewModel.vehicles) { vehicle in
                        Annotation(vehicle.vehicleId, coordinate: .init(latitude: vehicle.location.lat, longitude: vehicle.location.lon)) {
                            Image(systemName: "bus.fill")
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(MTDRouteColor.display(hex: route.routeColor))
                                .clipShape(Circle())
                        }
                    }
                    if viewModel.stopTimes.count > 1 {
                        MapPolyline(coordinates: viewModel.stopTimes.map { .init(latitude: $0.stopPoint.stopLat, longitude: $0.stopPoint.stopLon) })
                            .stroke(MTDRouteColor.display(hex: route.routeColor), lineWidth: 3)
                    }
                }
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
                .onChange(of: viewModel.stopTimes) { _, stopTimes in fitCamera(stopTimes: stopTimes) }
                .onChange(of: viewModel.vehicles) { _, vehicles in
                    if viewModel.stopTimes.isEmpty { fitCamera(vehicles: vehicles) }
                }
            }

            if !viewModel.reroutes.isEmpty {
                Section("Active Detours") {
                    ForEach(viewModel.reroutes) { reroute in
                        VStack(alignment: .leading) {
                            Text(reroute.message).font(.subheadline.bold())
                            if let description = reroute.description {
                                Text(description).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Live Buses") {
                if let error = viewModel.vehiclesError, viewModel.vehicles.isEmpty {
                    ErrorStateView(error: error) { Task { await viewModel.refreshVehicles() } }
                } else if viewModel.vehicles.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No buses are running on \(route.routeLongName) right now.")
                            .font(.subheadline)
                        Text("MTD routes vary a lot by time of day — many reduce or stop service in the evening, overnight, and on weekends. This isn't a bug in the app; it reflects MTD's live feed. Check back during the route's normal service hours, or see the stop detail page for scheduled (non-live) departure times.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(viewModel.vehicles) { vehicle in
                        HStack {
                            Image(systemName: "bus.fill").foregroundStyle(MTDRouteColor.display(hex: route.routeColor))
                            VStack(alignment: .leading) {
                                Text(vehicle.trip.tripHeadsign).font(.caption.bold())
                                Text("Next stop: \(nextStopName(vehicle.nextStopId))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !viewModel.stopTimes.isEmpty {
                Section("Stops in Order") {
                    ForEach(viewModel.stopTimes) { stopTime in
                        HStack {
                            Text("\(stopTime.sequenceNumber)").font(.caption).foregroundStyle(.secondary).frame(width: 24)
                            Text(stopTime.stopPoint.stopName)
                            Spacer()
                            Text(stopTime.arrivalTime).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if viewModel.vehicles.isEmpty {
                Section("Stops in Order") {
                    Text("This list is built from an active bus's trip, so it's only available while at least one bus is running on this route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(route.routeLongName)
        .task { viewModel.startAutoRefresh() }
        .onDisappear { viewModel.stopAutoRefresh() }
    }

    private func fitCamera(stopTimes: [MTDStopTime] = [], vehicles: [MTDVehicle] = []) {
        let stopCoords = stopTimes.map { CLLocationCoordinate2D(latitude: $0.stopPoint.stopLat, longitude: $0.stopPoint.stopLon) }
        let vehicleCoords = vehicles.map { CLLocationCoordinate2D(latitude: $0.location.lat, longitude: $0.location.lon) }
        let coords = stopCoords + vehicleCoords
        guard !coords.isEmpty else { return }

        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.4, 0.01),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.4, 0.01)
        )
        withAnimation {
            cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

    private func nextStopName(_ rawStopId: String?) -> String {
        guard let rawStopId else { return "—" }
        let parentId = String(rawStopId.split(separator: ":").first ?? Substring(rawStopId))
        return catalog.stopsById[parentId]?.stopName ?? rawStopId
    }
}
