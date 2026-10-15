import Foundation

enum MTDServiceError: Error, LocalizedError {
    case noNetwork
    case rateLimited
    case apiError(code: Int, message: String)
    case decodingFailed
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No network connection. Showing the last data we had, if any."
        case .rateLimited:
            return "MTD's API is being called too often right now. Try again in a bit."
        case .apiError(_, let message):
            return "MTD's API had a problem: \(message)"
        case .decodingFailed:
            return "MTD sent back something this version of the app doesn't understand yet."
        case .missingAPIKey:
            return "No MTD API key is configured. Add one in Secrets.xcconfig."
        }
    }
}

/// Everything the app needs from MTD's bus data, behind a protocol so a future
/// `MTDServiceV3` (https://mtd.dev) can swap in without touching any view or view model.
protocol MTDService {
    func getRoutes() async throws -> [MTDRoute]
    func getStops() async throws -> [MTDStop]
    func getStopsByLatLon(lat: Double, lon: Double) async throws -> [MTDStop]
    func getDeparturesByStop(stopId: String) async throws -> [MTDDeparture]
    func getVehiclesByRoute(routeId: String) async throws -> [MTDVehicle]
    func getStopTimesByTrip(tripId: String) async throws -> [MTDStopTime]
    func getReroutes() async throws -> [MTDReroute]
    func getReroutesByRoute(routeId: String) async throws -> [MTDReroute]

    /// Raw JSON for the trip planner endpoints — see MTDTripPlanner.swift for why this isn't
    /// a typed Decodable return (the endpoint is down and MTD's docs don't show a live sample).
    func getPlannedTripsByStops(originStopId: String, destinationStopId: String, date: String, time: String, arriveDepart: String) async throws -> Data
    func getPlannedTripsByLatLon(originLat: Double, originLon: Double, destinationLat: Double, destinationLon: Double, date: String, time: String, arriveDepart: String) async throws -> Data
}

/// Simple hourly request counter so the app can show "rate limited" instead of silently
/// hammering a 1,000 req/hour key. Not a hard client-side cap — MTD's server is the real
/// enforcer — just an early, friendlier warning.
actor MTDRateLimiter {
    static let shared = MTDRateLimiter()
    private var windowStart = Date()
    private var count = 0
    private let limit = 900 // leave headroom under MTD's 1,000/hour

    func recordAndCheck() -> Bool {
        let now = Date()
        if now.timeIntervalSince(windowStart) > 3600 {
            windowStart = now
            count = 0
        }
        count += 1
        return count <= limit
    }
}

final class MTDServiceV2: MTDService {
    private let baseURL = URL(string: "https://developer.cumtd.com/api/v2.2/json/")!
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String = MTDServiceV2.apiKeyFromInfoPlist(), session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    static func apiKeyFromInfoPlist() -> String {
        Bundle.main.object(forInfoDictionaryKey: "MTD_API_KEY") as? String ?? ""
    }

    private func request(_ method: String, params: [String: String] = [:]) async throws -> Data {
        guard !apiKey.isEmpty else { throw MTDServiceError.missingAPIKey }
        guard await MTDRateLimiter.shared.recordAndCheck() else { throw MTDServiceError.rateLimited }

        var components = URLComponents(url: baseURL.appendingPathComponent(method), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "key", value: apiKey)]
        items.append(contentsOf: params.map { URLQueryItem(name: $0.key, value: $0.value) })
        components.queryItems = items

        let (data, response) = try await fetch(components.url!)
        try Self.validateStatus(data: data, response: response)
        return data
    }

    private func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(from: url)
        } catch {
            throw MTDServiceError.noNetwork
        }
    }

    private static func validateStatus(data: Data, response: URLResponse) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let status = json["status"] as? [String: Any],
              let code = status["code"] as? Int else {
            return // let the caller's Decodable attempt fail with a clearer decodingFailed error
        }
        if code != 200 {
            let msg = status["msg"] as? String ?? "Unknown error"
            throw MTDServiceError.apiError(code: code, message: msg)
        }
    }

    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try MTDDateCoding.makeDecoder().decode(type, from: data)
        } catch {
            throw MTDServiceError.decodingFailed
        }
    }

    func getRoutes() async throws -> [MTDRoute] {
        if let cached = await MTDCache.shared.load(.routes, as: [MTDRoute].self) { return cached }
        let data = try await request("GetRoutes")
        let routes = try decode(data, as: MTDRoutesResponse.self).routes
        await MTDCache.shared.save(routes, for: .routes)
        return routes
    }

    func getStops() async throws -> [MTDStop] {
        if let cached = await MTDCache.shared.load(.stops, as: [MTDStop].self) { return cached }
        let data = try await request("GetStops")
        let stops = try decode(data, as: MTDStopsResponse.self).stops
        await MTDCache.shared.save(stops, for: .stops)
        return stops
    }

    func getStopsByLatLon(lat: Double, lon: Double) async throws -> [MTDStop] {
        let data = try await request("GetStopsByLatLon", params: ["lat": String(lat), "lon": String(lon)])
        return try decode(data, as: MTDStopsResponse.self).stops
    }

    func getDeparturesByStop(stopId: String) async throws -> [MTDDeparture] {
        let data = try await request("GetDeparturesByStop", params: ["stop_id": stopId])
        return try decode(data, as: MTDDeparturesResponse.self).departures
    }

    func getVehiclesByRoute(routeId: String) async throws -> [MTDVehicle] {
        let data = try await request("GetVehiclesByRoute", params: ["route_id": routeId])
        return try decode(data, as: MTDVehiclesResponse.self).vehicles
    }

    func getStopTimesByTrip(tripId: String) async throws -> [MTDStopTime] {
        let data = try await request("GetStopTimesByTrip", params: ["trip_id": tripId])
        return try decode(data, as: MTDStopTimesResponse.self).stopTimes
    }

    func getReroutes() async throws -> [MTDReroute] {
        let data = try await request("GetReroutes")
        return try decode(data, as: MTDReroutesResponse.self).reroutes
    }

    func getReroutesByRoute(routeId: String) async throws -> [MTDReroute] {
        let data = try await request("GetReroutesByRoute", params: ["route_id": routeId])
        return try decode(data, as: MTDReroutesResponse.self).reroutes
    }

    func getPlannedTripsByStops(originStopId: String, destinationStopId: String, date: String, time: String, arriveDepart: String) async throws -> Data {
        try await request("GetPlannedTripsByStops", params: [
            "origin_stop_id": originStopId,
            "destination_stop_id": destinationStopId,
            "date": date,
            "time": time,
            "arrive_depart": arriveDepart
        ])
    }

    func getPlannedTripsByLatLon(originLat: Double, originLon: Double, destinationLat: Double, destinationLon: Double, date: String, time: String, arriveDepart: String) async throws -> Data {
        try await request("GetPlannedTripsByLatLon", params: [
            "origin_lat": String(originLat),
            "origin_lon": String(originLon),
            "destination_lat": String(destinationLat),
            "destination_lon": String(destinationLon),
            "date": date,
            "time": time,
            "arrive_depart": arriveDepart
        ])
    }
}
