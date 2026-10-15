import ActivityKit
import WidgetKit
import SwiftUI

struct BusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusActivityAttributes.self) { context in
            lockScreenView(context: context)
                .activityBackgroundTint(IlliniColor.navy)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.classTitle).font(.caption.bold()).lineLimit(1)
                        Text(context.state.boardingStopName).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date.now...context.state.leaveTime, countsDown: true)
                        .font(.title3.bold())
                        .monospacedDigit()
                        .foregroundStyle(IlliniColor.orange)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        if let route = context.state.routeShortName {
                            RouteBadge(shortName: route, colorHex: "FF5F05", textColorHex: "FFFFFF")
                        }
                        Text(context.state.isLive ? "Live GPS" : "Scheduled")
                            .font(.caption2)
                            .foregroundStyle(context.state.isLive ? .green : .secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "bus.fill").foregroundStyle(IlliniColor.orange)
            } compactTrailing: {
                Text(timerInterval: Date.now...context.state.leaveTime, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "bus.fill").foregroundStyle(IlliniColor.orange)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<BusActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.classTitle).font(.headline).foregroundStyle(.white)
                Text("Board at \(context.state.boardingStopName)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Leave in").font(.caption2).foregroundStyle(.white.opacity(0.7))
                Text(timerInterval: Date.now...context.state.leaveTime, countsDown: true)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(IlliniColor.orange)
            }
        }
        .padding()
    }
}
