import Foundation

/// A single bus leg pulled out of a GetPlannedTripsByStops / GetPlannedTripsByLatLon response.
struct PlannedBusLeg: Equatable {
    let routeId: String
    let tripId: String?
    let boardingStopId: String
    let boardTime: Date
    let arriveTime: Date
}

/// Parses the trip-planner response defensively instead of as a strict `Decodable` model.
///
/// Why: as of 2026-10-14, GetPlannedTripsByStops and GetPlannedTripsByLatLon return HTTP-body
/// status 500 for every input (different stop pairs, with/without date & time, JSON and XML) —
/// see README "Known MTD API issues". MTD's prose docs describe an `itineraries` list of
/// itinerary objects each containing a leg list with `walk`/`service` legs and `begin`/`end`
/// points, but show no literal JSON sample, so the exact nesting is unconfirmed. Rather than
/// guess a strict schema that silently breaks the whole alert feature the day the endpoint
/// comes back with a slightly different shape than guessed, this walks the decoded JSON
/// looking for the fields it actually needs and returns nil (triggering the schedule-based
/// fallback in BusAlertPlanner) if anything doesn't match. Re-run the probe in the README and
/// tighten this once the endpoint is confirmed working.
enum MTDTripPlannerParser {
    static func firstBusLeg(from data: Data) -> PlannedBusLeg? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let itineraries = (json["itineraries"] as? [[String: Any]]) ?? (json["trips"] as? [[String: Any]]),
              let itinerary = itineraries.first else { return nil }
        let legs = (itinerary["itinerary"] as? [[String: Any]]) ?? (itinerary["legs"] as? [[String: Any]]) ?? []

        for leg in legs {
            let service = (leg["service"] as? [String: Any]) ?? leg
            guard let routeId = service["route_id"] as? String,
                  let begin = leg["begin"] as? [String: Any],
                  let end = leg["end"] as? [String: Any],
                  let boardingStopId = begin["stop_id"] as? String,
                  let boardTime = date(from: begin["time"] ?? begin["depart_time"]),
                  let arriveTime = date(from: end["time"] ?? end["arrive_time"]) else {
                continue
            }
            let tripId = service["trip_id"] as? String
            return PlannedBusLeg(routeId: routeId, tripId: tripId, boardingStopId: boardingStopId, boardTime: boardTime, arriveTime: arriveTime)
        }
        return nil
    }

    private static func date(from value: Any?) -> Date? {
        guard let string = value as? String else { return nil }
        return MTDDateCoding.formatter.date(from: string)
    }
}
