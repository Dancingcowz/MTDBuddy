import SwiftUI

struct RoutesView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @State private var searchText = ""

    private var isSearching: Bool { !searchText.isEmpty }

    private var searchResults: [MTDRoute] {
        catalog.routes.filter {
            $0.routeLongName.localizedCaseInsensitiveContains(searchText) ||
            $0.routeShortName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if catalog.isLoading && catalog.routes.isEmpty {
                    LoadingStateView()
                } else if let error = catalog.loadError, catalog.routes.isEmpty {
                    ErrorStateView(error: error) { Task { await catalog.reload() } }
                } else {
                    List {
                        if !isSearching {
                            Section {
                                NavigationLink(value: DetoursDestination()) {
                                    Label("Detours", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(IlliniColor.orange)
                                }
                            }
                            Section {
                                ForEach(catalog.popularRoutes) { route in
                                    NavigationLink(value: route) { RouteRow(route: route) }
                                }
                            } footer: {
                                Text("MTD runs \(catalog.routes.count) route variants in total (evening, Saturday, Sunday, alternates, …) — search above to find any of them.")
                            }
                        } else if searchResults.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            Section {
                                ForEach(searchResults) { route in
                                    NavigationLink(value: route) { RouteRow(route: route) }
                                }
                            }
                        }
                    }
                    .refreshable { await catalog.reload() }
                }
            }
            .navigationTitle("Routes")
            .searchable(text: $searchText, prompt: "Search all routes")
            .navigationDestination(for: MTDRoute.self) { RouteDetailView(route: $0) }
            .navigationDestination(for: DetoursDestination.self) { _ in DetoursView() }
        }
    }
}

private struct RouteRow: View {
    let route: MTDRoute
    var body: some View {
        HStack {
            RouteBadge(shortName: route.routeShortName, colorHex: route.routeColor, textColorHex: route.routeTextColor)
            Text(route.routeLongName)
        }
    }
}

struct DetoursDestination: Hashable {}
