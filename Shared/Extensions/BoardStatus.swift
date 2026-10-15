import SwiftUI

/// "Minutes left colored by walk time ... with a text label too, not color alone" (Home spec).
enum BoardStatus {
    case onTime, hurry, tooLate

    init(minutesUntilDeparture: Int, walkMinutes: Int) {
        if minutesUntilDeparture >= walkMinutes + 3 {
            self = .onTime
        } else if minutesUntilDeparture >= walkMinutes {
            self = .hurry
        } else {
            self = .tooLate
        }
    }

    var label: String {
        switch self {
        case .onTime: return "On time"
        case .hurry: return "Hurry"
        case .tooLate: return "Too late"
        }
    }

    var color: Color {
        switch self {
        case .onTime: return .green
        case .hurry: return IlliniColor.orange
        case .tooLate: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .onTime: return "checkmark.circle.fill"
        case .hurry: return "exclamationmark.triangle.fill"
        case .tooLate: return "xmark.octagon.fill"
        }
    }
}
