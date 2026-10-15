import SwiftUI

struct StopsView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var locationManager: LocationManager
    @StateObject private var viewModel = StopsViewModel()
    @State private var showPlaceSearch = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Stops")
                .searchable(text: $viewModel.searchText, prompt: "Search stops")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPlaceSearch = true
                        } label: {
                            Label("Find near a place", systemImage: "mappin.and.ellipse")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.sortByNearest.toggle()
                            if viewModel.sortByNearest {
                                locationManager.requestPermission()
                                locationManager.requestOneShot()
                            }
                        } label: {
                            Label("Nearest to me", systemImage: viewModel.sortByNearest ? "location.fill" : "location")
                        }
                    }
                }
                .sheet(isPresented: $showPlaceSearch) { PlaceSearchStopsView() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if catalog.isLoading && catalog.stops.isEmpty {
            LoadingStateView()
        } else if let error = catalog.loadError, catalog.stops.isEmpty {
            ErrorStateView(error: error) { Task { await catalog.reload() } }
        } else {
            let filtered = viewModel.filteredStops(from: catalog.stops, userLocation: locationManager.location)
            List {
                if viewModel.sortByNearest || !viewModel.searchText.isEmpty {
                    ForEach(filtered) { stop in
                        NavigationLink(value: stop) { StopRow(stop: stop) }
                    }
                } else {
                    ForEach(viewModel.sections(from: filtered), id: \.letter) { section in
                        Section(section.letter) {
                            ForEach(section.stops) { stop in
                                NavigationLink(value: stop) { StopRow(stop: stop) }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: MTDStop.self) { StopDetailView(stop: $0) }
            .refreshable { await catalog.reload() }
        }
    }
}

private struct StopRow: View {
    let stop: MTDStop
    var body: some View {
        VStack(alignment: .leading) {
            Text(stop.stopName).font(.body)
            Text(stop.code).font(.caption).foregroundStyle(.secondary)
        }
    }
}
