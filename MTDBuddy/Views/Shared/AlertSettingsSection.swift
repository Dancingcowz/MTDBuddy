import SwiftUI

/// Home stop/walk time + heads-up/arrive-early minutes + test-notification button.
/// Embedded in both the Classes tab (per spec) and the Home settings sheet.
struct AlertSettingsSection: View {
    @EnvironmentObject private var catalog: CatalogStore
    @Binding var settings: UserSettings
    @State private var showStopPicker = false

    var body: some View {
        Section("Alert Settings") {
            Button {
                showStopPicker = true
            } label: {
                HStack {
                    Text("Home stop")
                    Spacer()
                    Text(settings.homeStopId.map { catalog.stopName($0) } ?? "Not set")
                        .foregroundStyle(.secondary)
                }
            }
            Stepper("Home walk time: \(settings.homeWalkMinutes) min", value: $settings.homeWalkMinutes, in: 1...30)
                .onChange(of: settings.homeWalkMinutes) { _, _ in settings.save() }

            Stepper("Heads-up: \(settings.headsUpMinutes) min before", value: $settings.headsUpMinutes, in: 1...30)
                .onChange(of: settings.headsUpMinutes) { _, _ in settings.save() }
            Stepper("Arrive early: \(settings.arriveEarlyMinutes) min", value: $settings.arriveEarlyMinutes, in: 0...20)
                .onChange(of: settings.arriveEarlyMinutes) { _, _ in settings.save() }

            Button("Send Test Notification") {
                NotificationManager.shared.sendTestNotification(boardingStopId: settings.homeStopId)
            }
        }
        .sheet(isPresented: $showStopPicker) {
            StopPickerView { stop in
                settings.homeStopId = stop.stopId
                settings.save()
            }
        }
    }
}
