import Foundation

// Field names and shapes below were captured from live calls to
// https://developer.cumtd.com/api/v2.2/json/<Method> on 2026-10-14, not guessed.
// Sample payloads live in the repo README's "API notes" section.

struct MTDEnvelope<T: Decodable>: Decodable {
    let status: MTDStatus
    let payload: T

    enum CodingKeys: String, CodingKey { case status }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(MTDStatus.self, forKey: .status)
        payload = try T(from: decoder)
    }
}

struct MTDStatus: Decodable {
    let code: Int
    let msg: String
}

struct MTDRoute: Codable, Identifiable, Hashable {
    let routeId: String
    let routeShortName: String
    let routeLongName: String
    let routeColor: String
    let routeTextColor: String

    var id: String { routeId }

    enum CodingKeys: String, CodingKey {
        case routeId = "route_id"
        case routeShortName = "route_short_name"
        case routeLongName = "route_long_name"
        case routeColor = "route_color"
        case routeTextColor = "route_text_color"
    }
}

struct MTDRoutesResponse: Decodable {
    let routes: [MTDRoute]
}

struct MTDStopPoint: Codable, Hashable {
    let code: String
    let stopId: String
    let stopLat: Double
    let stopLon: Double
    let stopName: String

    enum CodingKeys: String, CodingKey {
        case code
        case stopId = "stop_id"
        case stopLat = "stop_lat"
        case stopLon = "stop_lon"
        case stopName = "stop_name"
    }
}

struct MTDStop: Codable, Identifiable, Hashable {
    let stopId: String
    let stopName: String
    let code: String
    let distance: Double?
    let stopPoints: [MTDStopPoint]

    var id: String { stopId }

    /// Centroid of this stop's boarding points — used for maps and "nearest to me" when
    /// the parent stop itself carries no lat/lon (v2.2 doesn't return one).
    var centerLat: Double {
        guard !stopPoints.isEmpty else { return 0 }
        return stopPoints.map(\.stopLat).reduce(0, +) / Double(stopPoints.count)
    }
    var centerLon: Double {
        guard !stopPoints.isEmpty else { return 0 }
        return stopPoints.map(\.stopLon).reduce(0, +) / Double(stopPoints.count)
    }

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case stopName = "stop_name"
        case code
        case distance
        case stopPoints = "stop_points"
    }
}

struct MTDStopsResponse: Decodable {
    let stops: [MTDStop]
}

struct MTDTripRef: Decodable, Hashable {
    let tripId: String
    let tripHeadsign: String
    let routeId: String
    let blockId: String
    let direction: String
    let serviceId: String
    let shapeId: String

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case tripHeadsign = "trip_headsign"
        case routeId = "route_id"
        case blockId = "block_id"
        case direction
        case serviceId = "service_id"
        case shapeId = "shape_id"
    }
}

struct MTDLatLon: Decodable, Hashable {
    let lat: Double
    let lon: Double
}

struct MTDStopRef: Decodable, Hashable {
    let stopId: String
    enum CodingKeys: String, CodingKey { case stopId = "stop_id" }
}

struct MTDDeparture: Decodable, Identifiable, Hashable {
    let stopId: String
    let headsign: String
    let route: MTDRoute
    let trip: MTDTripRef
    let vehicleId: String?
    let origin: MTDStopRef
    let destination: MTDStopRef
    let isMonitored: Bool
    let isScheduled: Bool
    let isIstop: Bool
    let scheduled: Date
    let expected: Date
    let expectedMins: Int
    let location: MTDLatLon?

    var id: String { "\(stopId)-\(trip.tripId)-\(scheduled.timeIntervalSince1970)" }

    /// True "live" GPS-backed prediction vs a static schedule fallback.
    var isLive: Bool { isMonitored }

    enum CodingKeys: String, CodingKey {
        case stopId = "stop_id"
        case headsign, route, trip
        case vehicleId = "vehicle_id"
        case origin, destination
        case isMonitored = "is_monitored"
        case isScheduled = "is_scheduled"
        case isIstop = "is_istop"
        case scheduled, expected
        case expectedMins = "expected_mins"
        case location
    }
}

struct MTDDeparturesResponse: Decodable {
    let departures: [MTDDeparture]
}

struct MTDVehicle: Decodable, Identifiable, Hashable {
    let vehicleId: String
    let trip: MTDTripRef
    let location: MTDLatLon
    let previousStopId: String?
    let nextStopId: String?
    let originStopId: String?
    let destinationStopId: String?
    let lastUpdated: Date

    var id: String { vehicleId }

    enum CodingKeys: String, CodingKey {
        case vehicleId = "vehicle_id"
        case trip, location
        case previousStopId = "previous_stop_id"
        case nextStopId = "next_stop_id"
        case originStopId = "origin_stop_id"
        case destinationStopId = "destination_stop_id"
        case lastUpdated = "last_updated"
    }
}

struct MTDVehiclesResponse: Decodable {
    let vehicles: [MTDVehicle]
}

struct MTDStopTime: Decodable, Identifiable, Hashable {
    let arrivalTime: String
    let departureTime: String
    let stopSequence: String
    let stopPoint: MTDStopPoint

    var id: String { "\(stopPoint.stopId)-\(stopSequence)" }
    var sequenceNumber: Int { Int(stopSequence) ?? 0 }

    enum CodingKeys: String, CodingKey {
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case stopSequence = "stop_sequence"
        case stopPoint = "stop_point"
    }
}

struct MTDStopTimesResponse: Decodable {
    let stopTimes: [MTDStopTime]
    enum CodingKeys: String, CodingKey { case stopTimes = "stop_times" }
}

/// NOTE: GetReroutes/GetReroutesByRoute returned zero active reroutes while this was built
/// (see README "Known MTD API issues"), so `affected_routes`'s exact shape (route objects vs.
/// plain route_id strings) couldn't be confirmed against live data — only against the prose
/// docs at developer.cumtd.com. This decodes either shape defensively rather than crashing.
struct MTDReroute: Decodable, Identifiable, Hashable {
    let message: String
    let description: String?
    let startDate: String?
    let endDate: String?
    let affectedRouteIds: [String]

    var id: String { "\(message)-\(startDate ?? "")-\(affectedRouteIds.joined())" }

    enum CodingKeys: String, CodingKey {
        case message, description
        case startDate = "start_date"
        case endDate = "end_date"
        case affectedRoutes = "affected_routes"
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)

        if let routeObjects = try? container.decodeIfPresent([MTDRoute].self, forKey: .affectedRoutes) {
            affectedRouteIds = routeObjects.map(\.routeId)
        } else if let ids = try? container.decodeIfPresent([String].self, forKey: .affectedRoutes) {
            affectedRouteIds = ids
        } else {
            affectedRouteIds = []
        }
    }
}

struct MTDReroutesResponse: Decodable {
    let reroutes: [MTDReroute]
}

// GetPlannedTripsByStops / GetPlannedTripsByLatLon have no strict Decodable model here —
// see MTDTripPlanner.swift for why (endpoint is down; docs prose is incomplete/unconfirmed)
// and how the response is parsed defensively instead.

enum MTDDateCoding {
    /// MTD emits "2026-10-14T18:00:00-05:00" — ISO8601 with a colon in the UTC offset,
    /// which `.withInternetDateTime` parses, but no fractional seconds, which it also expects
    /// unless we disable that option explicitly.
    static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(string)")
        }
        return decoder
    }
}
