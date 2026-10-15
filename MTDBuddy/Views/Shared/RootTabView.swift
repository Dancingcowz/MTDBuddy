import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var notificationManager: NotificationManager
    @StateObject private var catalog = CatalogStore(service: AppEnvironment.shared.mtdService)
    @State private var deepLinkStop: MTDStop?

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            StopsView()
                .tabItem { Label("Stops", systemImage: "mappin.and.ellipse") }
            RoutesView()
                .tabItem { Label("Routes", systemImage: "arrow.triangle.swap") }
            ClassesView()
                .tabItem { Label("Classes", systemImage: "graduationcap.fill") }
        }
        .tint(IlliniColor.orange)
        .environmentObject(catalog)
        .task { await catalog.loadIfNeeded() }
        .onChange(of: notificationManager.deepLinkStopId) { _, stopId in
            guard let stopId else { return }
            deepLinkStop = catalog.stopsById[stopId]
            notificationManager.deepLinkStopId = nil
        }
        .sheet(item: $deepLinkStop) { stop in
            NavigationStack {
                StopDetailView(stop: stop)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { deepLinkStop = nil }
                        }
                    }
            }
        }
    }
}
