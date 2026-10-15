import SwiftUI
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var calendarManager: GoogleCalendarManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var settings = UserSettings.load()
    @State private var notificationsGranted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Permissions") {
                    PermissionRow(
                        title: "Location", granted: locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
                    ) { locationManager.requestPermission() }
                    PermissionRow(title: "Notifications", granted: notificationsGranted) {
                        Task { notificationsGranted = await notificationManager.requestAuthorization() }
                    }
                }

                Section("Google Calendar") {
                    if calendarManager.isSignedIn {
                        HStack {
                            Text("Connected")
                            Spacer()
                            Button("Disconnect", role: .destructive) { calendarManager.signOut() }
                                .font(.caption)
                        }
                    } else {
                        Button("Connect Google Calendar") { Task { await calendarManager.signIn() } }
                    }
                }

                AlertSettingsSection(settings: $settings)

                Section {
                    LabeledContent("Cross-process sharing", value: AppGroupStore.isAvailable ? "Working" : "Unavailable (sideload)")
                } footer: {
                    Text("When unavailable, the widget still works independently via its own \"nearest stop\" configuration.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let request: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green).labelStyle(.iconOnly)
            } else {
                Button("Request", action: request)
                    .font(.caption)
            }
        }
    }
}
