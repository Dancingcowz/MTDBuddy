import SwiftUI

struct ClassesView: View {
    @EnvironmentObject private var calendarManager: GoogleCalendarManager
    @StateObject private var viewModel: ClassesViewModel

    init() {
        _viewModel = StateObject(wrappedValue: ClassesViewModel(calendar: AppEnvironment.shared.calendarManager))
    }

    var body: some View {
        NavigationStack {
            List {
                if !calendarManager.isSignedIn {
                    Section {
                        Button {
                            Task {
                                await calendarManager.signIn()
                                await viewModel.refreshClasses()
                            }
                        } label: {
                            Label("Connect Google Calendar", systemImage: "calendar.badge.plus")
                        }
                        if let error = calendarManager.lastError {
                            Text(error.localizedDescription).font(.caption).foregroundStyle(.secondary)
                        }
                    } footer: {
                        Text("Read-only access — MTD Buddy only reads your event titles, times, and locations to plan bus alerts. Nothing is ever written back to your calendar.")
                    }
                } else {
                    Section("Calendars") {
                        ForEach(viewModel.calendars) { calendar in
                            Button {
                                viewModel.toggleCalendar(calendar.id)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(Color(hex: calendar.backgroundColor ?? "999999"))
                                        .frame(width: 10, height: 10)
                                    Text(calendar.summary).foregroundStyle(.primary)
                                    Spacer()
                                    if viewModel.isCalendarSelected(calendar.id) {
                                        Image(systemName: "checkmark").foregroundStyle(IlliniColor.orange)
                                    }
                                }
                            }
                        }
                        Button("Disconnect Google Calendar", role: .destructive) {
                            calendarManager.signOut()
                        }
                        .font(.caption)
                    }

                    Section("Your Classes (next 14 days)") {
                        if viewModel.isLoadingClasses && viewModel.upcomingClasses.isEmpty {
                            Text("Loading…").font(.caption).foregroundStyle(.secondary)
                        } else if viewModel.upcomingClasses.isEmpty {
                            Text("No events found in the selected calendars.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(viewModel.upcomingClasses, id: \.title) { item in
                                ClassRow(
                                    title: item.title, nextStart: item.nextStart, location: item.location,
                                    config: Binding(
                                        get: { viewModel.config(for: item.title) },
                                        set: { viewModel.updateConfig($0) }
                                    )
                                )
                            }
                        }
                    }

                    AlertSettingsSection(settings: $viewModel.settings)
                }
            }
            .navigationTitle("Classes")
            .task { await viewModel.refreshClasses() }
            .refreshable { await viewModel.refreshClasses() }
        }
    }
}
