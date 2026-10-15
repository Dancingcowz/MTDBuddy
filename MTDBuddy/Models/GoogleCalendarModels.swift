import Foundation

/// A class occurrence, independent of where it came from — mirrors just the fields
/// BusAlertPlanner and the Classes tab actually need.
struct CalendarEvent: Hashable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
}

struct GCalCalendarListResponse: Decodable {
    let items: [GCalCalendarListEntry]
}

struct GCalCalendarListEntry: Decodable, Identifiable, Hashable {
    let id: String
    let summary: String
    let backgroundColor: String?
}

struct GCalEventsResponse: Decodable {
    let items: [GCalEventRaw]
}

struct GCalEventRaw: Decodable {
    let summary: String?
    let location: String?
    let start: GCalDateTime
    let end: GCalDateTime

    func toCalendarEvent() -> CalendarEvent? {
        guard let start = start.toDate(endOfDayIfAllDay: false),
              let end = end.toDate(endOfDayIfAllDay: true) else { return nil }
        return CalendarEvent(title: summary ?? "Untitled", startDate: start, endDate: end, location: location)
    }
}

/// Google represents a timed event as `dateTime` (RFC3339) and an all-day event as a plain
/// `date` (yyyy-MM-dd) — only one of the two is ever present.
struct GCalDateTime: Decodable {
    let dateTime: String?
    let date: String?

    func toDate(endOfDayIfAllDay: Bool) -> Date? {
        if let dateTime {
            return MTDDateCoding.formatter.date(from: dateTime)
        }
        if let date {
            guard let day = Self.dayFormatter.date(from: date) else { return nil }
            return endOfDayIfAllDay ? Calendar.current.date(byAdding: .day, value: 1, to: day) : day
        }
        return nil
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()
}
