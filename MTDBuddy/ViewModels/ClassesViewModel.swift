import Foundation

@MainActor
final class ClassesViewModel: ObservableObject {
    @Published var settings = UserSettings.load()
    @Published var upcomingClasses: [(title: String, nextStart: Date, location: String?)] = []
    @Published var configsById: [String: BusClassConfig] = [:]
    @Published var isLoadingClasses = false

    private let calendar: GoogleCalendarManager

    init(calendar: GoogleCalendarManager) {
        self.calendar = calendar
        configsById = Dictionary(uniqueKeysWithValues: BusClassConfig.loadAll().map { ($0.id, $0) })
    }

    var calendars: [GCalCalendarListEntry] { calendar.calendars }

    func isCalendarSelected(_ id: String) -> Bool { settings.selectedCalendarIds.contains(id) }

    func toggleCalendar(_ id: String) {
        settings = UserSettings.load()
        if settings.selectedCalendarIds.contains(id) {
            settings.selectedCalendarIds.removeAll { $0 == id }
        } else {
            settings.selectedCalendarIds.append(id)
        }
        settings.save()
        Task { await refreshClasses() }
    }

    func refreshClasses() async {
        settings = UserSettings.load()
        isLoadingClasses = true
        upcomingClasses = await calendar.uniqueUpcomingClasses(calendarIds: settings.selectedCalendarIds)
        isLoadingClasses = false
    }

    func config(for title: String) -> BusClassConfig {
        let key = BusClassConfig.key(forTitle: title)
        return configsById[key] ?? BusClassConfig(id: key, title: title)
    }

    func updateConfig(_ config: BusClassConfig) {
        configsById[config.id] = config
        BusClassConfig.saveAll(Array(configsById.values))
    }
}
