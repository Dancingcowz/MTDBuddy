import Foundation

/// On-disk cache for the two endpoints MTD asks clients to cache to stay under the
/// 1,000 req/hour key limit: stops (7 days) and routes (1 day). Stored in the App Group
/// container when available so the widget doesn't need its own network round trip, falling
/// back to the app's own Caches directory otherwise.
actor MTDCache {
    static let shared = MTDCache()

    enum Key: String {
        case stops = "mtd_cache_stops"
        case routes = "mtd_cache_routes"

        var maxAge: TimeInterval {
            switch self {
            case .stops: return 7 * 24 * 60 * 60
            case .routes: return 24 * 60 * 60
            }
        }
    }

    private struct Envelope<T: Codable>: Codable {
        let savedAt: Date
        let value: T
    }

    private var directory: URL {
        let base = AppGroupStore.containerURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MTDCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for key: Key) -> URL {
        directory.appendingPathComponent("\(key.rawValue).json")
    }

    func load<T: Codable>(_ key: Key, as type: T.Type) -> T? {
        guard let data = try? Data(contentsOf: fileURL(for: key)),
              let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: data) else {
            return nil
        }
        guard Date().timeIntervalSince(envelope.savedAt) < key.maxAge else { return nil }
        return envelope.value
    }

    func save<T: Codable>(_ value: T, for key: Key) {
        let envelope = Envelope(savedAt: Date(), value: value)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }
}
