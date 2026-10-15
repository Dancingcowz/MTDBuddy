import Foundation

/// Central point for anything shared between the app and the widget extension via the
/// `group.com.rexlan.mtdbuddy` App Group. Every accessor degrades to a sensible default
/// instead of crashing when the container isn't available — which happens whenever the app
/// is unsigned/sideloaded and the entitlement didn't survive re-signing (see README).
enum AppGroupStore {
    static let groupID = "group.com.rexlan.mtdbuddy"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    /// True once at app launch so Settings can tell the user whether cross-process sharing
    /// (widget favorites, Live Activity handoff) is actually working on this install.
    static var isAvailable: Bool { containerURL != nil && defaults != nil }

    static func save<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        if let defaults {
            defaults.set(data, forKey: key)
        } else {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let data = defaults?.data(forKey: key) ?? UserDefaults.standard.data(forKey: key)
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
