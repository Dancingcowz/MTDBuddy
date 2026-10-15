import Foundation

/// Implements the "Automatic alerts" rules from the spec:
/// - Origin for each upcoming Bus class today is the previous class's stop if that class ended
///   within 2.5h, otherwise the home stop.
/// - Plan with GetPlannedTripsByStops (arrive_depart=arrive, at class start − arrive-early
///   minutes), pick the latest bus that still arrives in time, leave time = boarding time −
///   walk time.
/// - Two local notifications (heads-up, leave-now); tapping either opens the boarding stop.
/// - Within 60 min of boarding, refine against live GetDeparturesByStop by trip_id.
/// - If no trip is found at all (currently always true — see MTDTripPlanner.swift), one alert
///   at class start − 25 min.
@MainActor
final class BusAlertPlanner {
    private let calendar: GoogleCalendarManager
    private let service: MTDService
    private let notifications: NotificationManager

    init(calendar: GoogleCalendarManager, service: MTDService, notifications: NotificationManager) {
        self.calendar = calendar
        self.service = service
        self.notifications = notifications
    }

    /// Re-plans every Bus-marked class still ahead today. Call on launch, from the
    /// BGAppRefreshTask, and from the "Plan today's bus alerts" App Intent.
    func planToday() async {
        let settings = UserSettings.load()
        await checkServiceAlerts(settings: settings)

        guard calendar.isSignedIn else { return }
        let configs = Dictionary(uniqueKeysWithValues: BusClassConfig.loadAll().map { ($0.id, $0) })
        let todays = await calendar.todaysEvents(calendarIds: settings.selectedCalendarIds)
        guard !todays.isEmpty else { return }

        var bestUpcomingPlan: TodayPlan?

        for (index, event) in todays.enumerated() {
            guard event.startDate > Date() else { continue }
            let key = BusClassConfig.key(forTitle: event.title)
            guard let config = configs[key], config.isBusClass, let destinationStopId = config.stopId else { continue }

            let (originStopId, originWalkMinutes) = resolveOrigin(
                forEventAt: index, in: todays, configs: configs, settings: settings
            )
            guard let originStopId else { continue }

            let plan = await planAndSchedule(
                classKey: key,
                classTitle: event.title,
                classStart: event.startDate,
                originStopId: originStopId,
                originWalkMinutes: originWalkMinutes,
                destinationStopId: destinationStopId,
                arriveEarlyMinutes: settings.arriveEarlyMinutes,
                headsUpMinutes: settings.headsUpMinutes
            )

            if let plan, bestUpcomingPlan == nil || plan.leaveTime < bestUpcomingPlan!.leaveTime {
                bestUpcomingPlan = plan
            }
        }

        if let bestUpcomingPlan {
            bestUpcomingPlan.save()
            LiveActivityManager.shared.update(plan: bestUpcomingPlan)
        } else {
            TodayPlan.clear()
            LiveActivityManager.shared.end()
        }
    }

    /// Previous class's stop if it ended within 2.5h of this one starting; otherwise home.
    private func resolveOrigin(
        forEventAt index: Int,
        in todays: [CalendarEvent],
        configs: [String: BusClassConfig],
        settings: UserSettings
    ) -> (stopId: String?, walkMinutes: Int) {
        guard index > 0 else {
            return (settings.homeStopId, settings.homeWalkMinutes)
        }
        let previous = todays[index - 1]
        let current = todays[index]
        let gap = current.startDate.timeIntervalSince(previous.endDate)
        guard gap >= 0, gap <= 2.5 * 3600 else {
            return (settings.homeStopId, settings.homeWalkMinutes)
        }
        let prevKey = BusClassConfig.key(forTitle: previous.title)
        if let prevConfig = configs[prevKey], let prevStop = prevConfig.stopId {
            return (prevStop, prevConfig.walkMinutes)
        }
        return (settings.homeStopId, settings.homeWalkMinutes)
    }

    @discardableResult
    private func planAndSchedule(
        classKey: String,
        classTitle: String,
        classStart: Date,
        originStopId: String,
        originWalkMinutes: Int,
        destinationStopId: String,
        arriveEarlyMinutes: Int,
        headsUpMinutes: Int
    ) async -> TodayPlan? {
        let arriveBy = classStart.addingTimeInterval(-Double(arriveEarlyMinutes) * 60)
        let plannedLeg = await fetchPlannedLeg(origin: originStopId, destination: destinationStopId, arriveBy: arriveBy)

        let boardTime: Date
        let routeId: String?
        let tripId: String?
        var isLive = false

        if let plannedLeg {
            boardTime = plannedLeg.boardTime
            routeId = plannedLeg.routeId
            tripId = plannedLeg.tripId
        } else {
            // Fallback: no trip plan available (endpoint down, or no service found) —
            // one alert at class start − 25 min, per spec.
            let fallbackFire = classStart.addingTimeInterval(-25 * 60)
            notifications.scheduleAlert(
                classKey: classKey, kind: .fallback, fireDate: fallbackFire,
                title: "Leave for \(classTitle)",
                body: "MTD Buddy couldn't fetch a live bus plan — leave now to be safe.",
                boardingStopId: originStopId
            )
            return TodayPlan(
                classTitle: classTitle, routeShortName: nil, routeColorHex: nil,
                boardingStopId: originStopId, boardingStopName: originStopId,
                leaveTime: fallbackFire, boardTime: fallbackFire, arriveTime: classStart,
                isLive: false
            )
        }

        // Refine against live departures within 60 minutes of boarding.
        var effectiveBoardTime = boardTime
        if let tripId, boardTime.timeIntervalSinceNow <= 3600 {
            if let live = await liveBoardTime(originStopId: originStopId, tripId: tripId) {
                effectiveBoardTime = live
                isLive = true
            }
        }

        let leaveTime = effectiveBoardTime.addingTimeInterval(-Double(originWalkMinutes) * 60)

        notifications.scheduleAlert(
            classKey: classKey, kind: .headsUp,
            fireDate: leaveTime.addingTimeInterval(-Double(headsUpMinutes) * 60),
            title: "Bus for \(classTitle) in \(headsUpMinutes) min",
            body: "Board route \(routeId ?? "") at your stop by \(Self.timeFormatter.string(from: effectiveBoardTime)).",
            boardingStopId: originStopId
        )
        notifications.scheduleAlert(
            classKey: classKey, kind: .leaveNow,
            fireDate: leaveTime,
            title: "Leave now for \(classTitle)",
            body: "Walk to your stop now to catch the \(Self.timeFormatter.string(from: effectiveBoardTime)) bus.",
            boardingStopId: originStopId
        )

        return TodayPlan(
            classTitle: classTitle, routeShortName: routeId, routeColorHex: nil,
            boardingStopId: originStopId, boardingStopName: originStopId,
            leaveTime: leaveTime, boardTime: effectiveBoardTime, arriveTime: classStart,
            isLive: isLive
        )
    }

    private func fetchPlannedLeg(origin: String, destination: String, arriveBy: Date) async -> PlannedBusLeg? {
        let date = DateFormatter.mtdDayStamp.string(from: arriveBy)
        let time = Self.hourMinuteFormatter.string(from: arriveBy)
        guard let data = try? await service.getPlannedTripsByStops(
            originStopId: origin, destinationStopId: destination, date: date, time: time, arriveDepart: "arrive"
        ) else { return nil }
        return MTDTripPlannerParser.firstBusLeg(from: data)
    }

    private func liveBoardTime(originStopId: String, tripId: String) async -> Date? {
        guard let departures = try? await service.getDeparturesByStop(stopId: originStopId) else { return nil }
        return departures.first { $0.trip.tripId == tripId }?.expected
    }

    // MARK: - Service alerts (detours)

    /// MTD's own site advertises route-specific service-change notifications as something
    /// riders want (mtd.org/UIUC), and this app already fetches reroute data for the Detours
    /// tab — it just never surfaced it proactively. This checks reroutes for every route that
    /// actually serves a stop the user cares about (home, favorites, class stops) and fires a
    /// one-time notification for any reroute it hasn't already notified about.
    ///
    /// Route membership is inferred from GetDeparturesByStop (there's no "routes for stop"
    /// endpoint in v2.2) — a route with no departures in that call's near-term window at a
    /// given stop won't be checked, which is a reasonable but imperfect heuristic.
    private func checkServiceAlerts(settings: UserSettings) async {
        var stopIds = Set(settings.favoriteStopIds)
        if let homeStopId = settings.homeStopId { stopIds.insert(homeStopId) }
        for config in BusClassConfig.loadAll() where config.isBusClass {
            if let stopId = config.stopId { stopIds.insert(stopId) }
        }
        guard !stopIds.isEmpty else { return }

        var routeIds = Set<String>()
        for stopId in stopIds {
            if let departures = try? await service.getDeparturesByStop(stopId: stopId) {
                routeIds.formUnion(departures.map(\.route.routeId))
            }
        }
        guard !routeIds.isEmpty else { return }

        var seen = Self.seenReroutes()
        for routeId in routeIds {
            guard let reroutes = try? await service.getReroutesByRoute(routeId: routeId) else { continue }
            for reroute in reroutes where !seen.contains(reroute.id) {
                seen.insert(reroute.id)
                notifications.sendServiceAlert(
                    title: "Service alert: \(routeId.capitalized)",
                    body: reroute.message,
                    boardingStopId: nil
                )
            }
        }
        Self.saveSeenReroutes(seen)
    }

    private static let seenReroutesKey = "mtd_seen_reroute_ids"

    private static func seenReroutes() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: seenReroutesKey) ?? [])
    }

    private static func saveSeenReroutes(_ ids: Set<String>) {
        UserDefaults.standard.set(Array(ids), forKey: seenReroutesKey)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    private static let hourMinuteFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
