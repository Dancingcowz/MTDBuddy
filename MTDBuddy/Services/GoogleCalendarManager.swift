import Combine
import Foundation

enum GoogleCalendarError: Error, LocalizedError {
    case apiError(Int)

    var errorDescription: String? {
        switch self {
        case .apiError(let code):
            return "Google Calendar API returned an error (\(code))."
        }
    }
}

/// Lists the user's Google calendars and the classes on them. Network-backed, so every call
/// is async and can fail.
@MainActor
final class GoogleCalendarManager: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published var calendars: [GCalCalendarListEntry] = []
    @Published var lastError: Error?

    private let oauth: GoogleOAuthManager
    private var cancellable: AnyCancellable?

    init(oauth: GoogleOAuthManager = .shared) {
        self.oauth = oauth
        isSignedIn = oauth.isSignedIn
        cancellable = oauth.$isSignedIn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] signedIn in
                self?.isSignedIn = signedIn
                if !signedIn { self?.calendars = [] }
            }
    }

    func signIn() async {
        do {
            try await oauth.signIn()
            await loadCalendars()
        } catch {
            lastError = error
        }
    }

    func signOut() {
        oauth.signOut()
        calendars = []
    }

    func loadCalendars() async {
        do {
            let items = try await fetchCalendarList()
            calendars = items.sorted { $0.summary < $1.summary }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Today's events across the given calendars, sorted by start time — what BusAlertPlanner
    /// walks to find "the previous class".
    func todaysEvents(calendarIds: [String]) async -> [CalendarEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return await events(calendarIds: calendarIds, timeMin: start, timeMax: end)
    }

    /// Unique class titles seen across the next 14 days, each with its soonest occurrence.
    func uniqueUpcomingClasses(calendarIds: [String]) async -> [(title: String, nextStart: Date, location: String?)] {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 14, to: start) ?? start
        let events = await events(calendarIds: calendarIds, timeMin: start, timeMax: end)

        var seen: [String: (title: String, nextStart: Date, location: String?)] = [:]
        for event in events {
            let key = BusClassConfig.key(forTitle: event.title)
            guard !key.isEmpty, seen[key] == nil else { continue }
            seen[key] = (title: event.title, nextStart: event.startDate, location: event.location)
        }
        return seen.values.sorted { $0.nextStart < $1.nextStart }
    }

    // MARK: - Networking

    private func events(calendarIds: [String], timeMin: Date, timeMax: Date) async -> [CalendarEvent] {
        guard !calendarIds.isEmpty else { return [] }
        var result: [CalendarEvent] = []
        for calendarId in calendarIds {
            if let events = try? await fetchEvents(calendarId: calendarId, timeMin: timeMin, timeMax: timeMax) {
                result.append(contentsOf: events)
            }
        }
        return result.sorted { $0.startDate < $1.startDate }
    }

    private func fetchCalendarList() async throws -> [GCalCalendarListEntry] {
        let token = try await oauth.validAccessToken()
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        return try JSONDecoder().decode(GCalCalendarListResponse.self, from: data).items
    }

    private func fetchEvents(calendarId: String, timeMin: Date, timeMax: Date) async throws -> [CalendarEvent] {
        let token = try await oauth.validAccessToken()
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedId)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: ISO8601DateFormatter().string(from: timeMin)),
            URLQueryItem(name: "timeMax", value: ISO8601DateFormatter().string(from: timeMax)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response)
        let decoded = try JSONDecoder().decode(GCalEventsResponse.self, from: data)
        return decoded.items.compactMap { $0.toCalendarEvent() }
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw GoogleCalendarError.apiError(code)
        }
    }
}
