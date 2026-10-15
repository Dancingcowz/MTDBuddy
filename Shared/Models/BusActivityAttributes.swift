import ActivityKit
import Foundation

/// Lock Screen / Dynamic Island Live Activity for the "Track on Lock Screen" button on Home.
struct BusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var leaveTime: Date
        var boardTime: Date
        var routeShortName: String?
        var boardingStopName: String
        var isLive: Bool
    }

    var classTitle: String
}
