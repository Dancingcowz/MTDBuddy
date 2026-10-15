import WidgetKit
import SwiftUI

struct MTDWidgetEntry: TimelineEntry {
    let date: Date
    let plan: TodayPlan?
    let departures: [MTDDeparture]
    let stopName: String
}

struct MTDWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MTDWidgetEntry {
        MTDWidgetEntry(date: .now, plan: nil, departures: [], stopName: "Illini Union")
    }

    func snapshot(for configuration: MTDWidgetConfigurationIntent, in context: Context) async -> MTDWidgetEntry {
        await buildEntry(configuration: configuration)
    }

    func timeline(for configuration: MTDWidgetConfigurationIntent, in context: Context) async -> Timeline<MTDWidgetEntry> {
        let entry = await buildEntry(configuration: configuration)
        // Widgets get a limited refresh budget; 10 min keeps this well within it while still
        // feeling fresh. The configured stop's departures also refresh whenever the user opens it.
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(10 * 60)))
    }

    private func buildEntry(configuration: MTDWidgetConfigurationIntent) async -> MTDWidgetEntry {
        let settings = UserSettings.load()
        let stopId = configuration.stop?.id ?? settings.mainFavoriteStopId
        let plan = TodayPlan.load()

        guard let stopId else {
            return MTDWidgetEntry(date: .now, plan: plan, departures: [], stopName: "Choose a stop")
        }

        var stopName = configuration.stop?.name ?? stopId
        var departures: [MTDDeparture] = []
        let service = MTDServiceV2()
        if let stops = try? await service.getStops(), let match = stops.first(where: { $0.stopId == stopId }) {
            stopName = match.stopName
        }
        if let fetched = try? await service.getDeparturesByStop(stopId: stopId) {
            departures = Array(fetched.prefix(3))
        }
        return MTDWidgetEntry(date: .now, plan: plan, departures: departures, stopName: stopName)
    }
}

struct MTDWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MTDWidgetEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            homeScreenView
        }
    }

    @ViewBuilder
    private var circularView: some View {
        if let plan = entry.plan {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text("Leave").font(.caption2)
                    Text(timerInterval: Date.now...plan.leaveTime, countsDown: true)
                        .font(.caption.bold())
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "bus.fill")
            }
        }
    }

    @ViewBuilder
    private var inlineView: some View {
        if let plan = entry.plan {
            Text("Leave: \(Text(timerInterval: Date.now...plan.leaveTime, countsDown: true))")
        } else if let next = entry.departures.first {
            Text("\(entry.stopName): \(next.expected.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("MTD Buddy")
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let plan = entry.plan {
                Text(plan.classTitle).font(.caption.bold()).lineLimit(1)
                Text(timerInterval: Date.now...plan.leaveTime, countsDown: true)
                    .font(.caption2)
                    .monospacedDigit()
            } else {
                Text(entry.stopName).font(.caption.bold()).lineLimit(1)
                ForEach(entry.departures.prefix(2)) { departure in
                    Text("\(departure.route.routeShortName) · \(departure.expected.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                }
            }
        }
    }

    private var homeScreenView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let plan = entry.plan {
                Text(plan.classTitle).font(.headline).lineLimit(1)
                Text("Leave in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(timerInterval: Date.now...plan.leaveTime, countsDown: true)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(IlliniColor.orange)
                Spacer(minLength: 0)
            }
            Text(entry.stopName).font(.caption.bold()).lineLimit(1)
            ForEach(entry.departures.prefix(entry.plan == nil ? 3 : 1)) { departure in
                HStack {
                    RouteBadge(shortName: departure.route.routeShortName, colorHex: departure.route.routeColor, textColorHex: departure.route.routeTextColor)
                    Text(departure.headsign).font(.caption2).lineLimit(1)
                    Spacer()
                    Text(departure.expected.formatted(date: .omitted, time: .shortened)).font(.caption2.bold())
                }
            }
        }
        .padding(4)
    }
}

struct MTDWidget: Widget {
    let kind = "MTDWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: MTDWidgetConfigurationIntent.self, provider: MTDWidgetProvider()) { entry in
            MTDWidgetEntryView(entry: entry)
                .containerBackground(IlliniColor.navy.gradient, for: .widget)
        }
        .configurationDisplayName("MTD Buddy")
        .description("Your next bus-class countdown and stop departures.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}
