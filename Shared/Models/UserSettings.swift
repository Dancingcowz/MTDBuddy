import Foundation

/// Persisted via AppGroupStore so both the app and the widget extension can read it.
struct UserSettings: Codable, Equatable {
    var homeStopId: String?
    var homeWalkMinutes: Int = 8
    var headsUpMinutes: Int = 10
    var arriveEarlyMinutes: Int = 5
    var selectedCalendarIds: [String] = []
    var favoriteStopIds: [String] = []
    /// Which favorite the widget shows by default when its own AppIntent config is left as "nearest".
    var mainFavoriteStopId: String?
    var walkMinutesByStopId: [String: Int] = [:]
    var hasCompletedOnboarding: Bool = false

    static let storageKey = "mtd_user_settings"

    static func load() -> UserSettings {
        AppGroupStore.load(UserSettings.self, forKey: storageKey) ?? UserSettings()
    }

    func save() {
        AppGroupStore.save(self, forKey: Self.storageKey)
    }

    func walkMinutes(toStop stopId: String) -> Int {
        walkMinutesByStopId[stopId] ?? homeWalkMinutes
    }
}

/// One of the user's classes, derived from a Google Calendar event title and configured by them
/// in the Classes tab. Keyed by a stable hash of the event title so it survives individual
/// calendar-event instances changing day to day.
struct BusClassConfig: Codable, Equatable, Identifiable {
    var id: String // stable key derived from the class title
    var title: String
    var isBusClass: Bool = true
    var stopId: String?
    var walkMinutes: Int = 8

    static let storageKey = "mtd_class_configs"

    static func loadAll() -> [BusClassConfig] {
        AppGroupStore.load([BusClassConfig].self, forKey: storageKey) ?? []
    }

    static func saveAll(_ configs: [BusClassConfig]) {
        AppGroupStore.save(configs, forKey: storageKey)
    }

    static func key(forTitle title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Today's resolved plan for a single Bus-marked class, shared to the widget/Live Activity.
struct TodayPlan: Codable, Equatable {
    var classTitle: String
    var routeShortName: String?
    var routeColorHex: String?
    var boardingStopId: String
    var boardingStopName: String
    var leaveTime: Date
    var boardTime: Date
    var arriveTime: Date
    var isLive: Bool

    static let storageKey = "mtd_today_plan"

    static func load() -> TodayPlan? {
        AppGroupStore.load(TodayPlan.self, forKey: storageKey)
    }

    func save() {
        AppGroupStore.save(self, forKey: Self.storageKey)
    }

    static func clear() {
        AppGroupStore.defaults?.removeObject(forKey: storageKey)
    }
}
