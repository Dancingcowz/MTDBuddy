import SwiftUI

struct DetoursView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @State private var reroutes: [MTDReroute] = []
    @State private var error: Error?
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading && reroutes.isEmpty {
                LoadingStateView()
            } else if let error, reroutes.isEmpty {
                ErrorStateView(error: error) { Task { await load() } }
            } else if reroutes.isEmpty {
                ContentUnavailableView("No Active Detours", systemImage: "checkmark.circle", description: Text("MTD isn't reporting any reroutes right now."))
            } else {
                List(reroutes) { reroute in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reroute.message).font(.subheadline.bold())
                        if let description = reroute.description {
                            Text(description).font(.caption).foregroundStyle(.secondary)
                        }
                        if !reroute.affectedRouteIds.isEmpty {
                            HStack {
                                ForEach(reroute.affectedRouteIds, id: \.self) { routeId in
                                    if let route = catalog.routesById[routeId] {
                                        RouteBadge(shortName: route.routeShortName, colorHex: route.routeColor, textColorHex: route.routeTextColor)
                                    } else {
                                        Text(routeId).font(.caption2)
                                    }
                                }
                            }
                        }
                    }
                }
                .refreshable { await load() }
            }
        }
        .navigationTitle("Detours")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        do {
            reroutes = try await AppEnvironment.shared.mtdService.getReroutes()
            error = nil
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
