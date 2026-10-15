import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let plan = viewModel.todayPlan {
                        NextClassCard(plan: plan, isTracking: LiveActivityManager.shared.isTracking) {
                            viewModel.toggleLiveActivity()
                        }
                    } else {
                        NoUpcomingClassCard()
                    }

                    if !viewModel.settings.favoriteStopIds.isEmpty {
                        Text("Favorite Stops")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(viewModel.settings.favoriteStopIds, id: \.self) { stopId in
                            FavoriteStopCard(
                                stopName: catalog.stopName(stopId),
                                departures: viewModel.favoriteDepartures[stopId] ?? [],
                                error: viewModel.favoriteErrors[stopId],
                                statusFor: { viewModel.status(for: $0, stopId: stopId) }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("MTD Buddy")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .task {
                await viewModel.refresh()
                viewModel.startAutoRefresh()
            }
            .onDisappear { viewModel.stopAutoRefresh() }
            .refreshable { await viewModel.refresh() }
        }
    }
}

private struct NoUpcomingClassCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bus.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8))
            Text("No upcoming Bus class today")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text("Mark a class Bus in the Classes tab to get leave-time alerts.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(IlliniColor.navy)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
