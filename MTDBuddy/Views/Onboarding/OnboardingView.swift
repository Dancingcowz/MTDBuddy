import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var calendarManager: GoogleCalendarManager
    @StateObject private var catalog = CatalogStore(service: AppEnvironment.shared.mtdService)
    @StateObject private var classesViewModel: ClassesViewModel

    @State private var step: Step = .welcome
    @State private var settings = UserSettings.load()
    @State private var notificationsGranted = false

    enum Step: Int, CaseIterable { case welcome, permissions, homeStop, calendars, classes }

    init(isComplete: Binding<Bool>) {
        _isComplete = isComplete
        _classesViewModel = StateObject(wrappedValue: ClassesViewModel(calendar: AppEnvironment.shared.calendarManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                .tint(IlliniColor.orange)
                .padding()

            Group {
                switch step {
                case .welcome: welcomeStep
                case .permissions: permissionsStep
                case .homeStop: homeStopStep
                case .calendars: calendarsStep
                case .classes: classesStep
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                if step != .welcome {
                    Button("Back") { back() }
                }
                Spacer()
                Button(step == .classes ? "Finish" : "Continue") { advance() }
                    .buttonStyle(.borderedProminent)
                    .tint(IlliniColor.orange)
            }
            .padding()
        }
        .environmentObject(catalog)
        .task { await catalog.loadIfNeeded() }
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "bus.fill").font(.system(size: 64)).foregroundStyle(IlliniColor.orange)
            Text("MTD Buddy").font(.largeTitle.bold())
            Text("Never miss your bus to class again.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MTD Buddy needs a few permissions").font(.title3.bold())
            PermissionButton(title: "Notifications", systemImage: "bell.fill", granted: notificationsGranted) {
                Task { notificationsGranted = await NotificationManager.shared.requestAuthorization() }
            }
            PermissionButton(title: "Location", systemImage: "location.fill", granted: locationManager.authorizationStatus == .authorizedWhenInUse) {
                locationManager.requestPermission()
            }
            Text("You'll connect Google Calendar next.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var homeStopStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Where's your home stop?").font(.title3.bold())
            Text("The bus stop you leave from, usually near where you live.")
                .font(.caption)
                .foregroundStyle(.secondary)
            StopPickerView(showCancelButton: false) { stop in
                settings.homeStopId = stop.stopId
                settings.save()
            }
        }
    }

    private var calendarsStep: some View {
        VStack(alignment: .leading) {
            Text("Which calendars have your classes?").font(.title3.bold()).padding()
            if !calendarManager.isSignedIn {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        Task {
                            await calendarManager.signIn()
                            await classesViewModel.refreshClasses()
                        }
                    } label: {
                        Label("Connect Google Calendar", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(IlliniColor.orange)
                    Text("Read-only — MTD Buddy only reads event titles, times, and locations.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                List(classesViewModel.calendars) { calendar in
                    Button {
                        classesViewModel.toggleCalendar(calendar.id)
                    } label: {
                        HStack {
                            Circle().fill(Color(hex: calendar.backgroundColor ?? "999999")).frame(width: 10, height: 10)
                            Text(calendar.summary).foregroundStyle(.primary)
                            Spacer()
                            if classesViewModel.isCalendarSelected(calendar.id) {
                                Image(systemName: "checkmark").foregroundStyle(IlliniColor.orange)
                            }
                        }
                    }
                }
            }
        }
    }

    private var classesStep: some View {
        VStack(alignment: .leading) {
            Text("Mark each class Bus or Walk").font(.title3.bold()).padding()
            List(classesViewModel.upcomingClasses, id: \.title) { item in
                ClassRow(
                    title: item.title, nextStart: item.nextStart, location: item.location,
                    config: Binding(
                        get: { classesViewModel.config(for: item.title) },
                        set: { classesViewModel.updateConfig($0) }
                    )
                )
            }
        }
    }

    private func advance() {
        if step == .calendars { Task { await classesViewModel.refreshClasses() } }
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            isComplete = true
        }
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }
}

private struct PermissionButton: View {
    let title: String
    let systemImage: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage).frame(width: 24)
                Text(title)
                Spacer()
                if granted {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text("Allow").foregroundStyle(IlliniColor.orange)
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
