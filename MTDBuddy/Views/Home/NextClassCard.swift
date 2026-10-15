import SwiftUI

struct NextClassCard: View {
    let plan: TodayPlan
    let isTracking: Bool
    let onToggleTracking: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(plan.classTitle)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                if let route = plan.routeShortName {
                    RouteBadge(shortName: route, colorHex: plan.routeColorHex ?? "6E6E6E", textColorHex: "FFFFFF")
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = plan.leaveTime.timeIntervalSince(context.date)
                VStack(alignment: .leading, spacing: 2) {
                    Text(remaining > 0 ? "Leave in" : "Leave now")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Text(plan.leaveTime.countdownString(from: context.date))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(IlliniColor.orange)
                        .monospacedDigit()
                }
            }

            HStack(spacing: 16) {
                InfoColumn(label: "Board at", value: plan.boardingStopName)
                InfoColumn(label: "Bus time", value: plan.boardTime.formatted(date: .omitted, time: .shortened))
                InfoColumn(label: "Arrive by", value: plan.arriveTime.formatted(date: .omitted, time: .shortened))
            }

            HStack {
                Label(plan.isLive ? "Live GPS" : "Scheduled", systemImage: plan.isLive ? "location.fill" : "clock")
                    .font(.caption.bold())
                    .foregroundStyle(plan.isLive ? .green : .white.opacity(0.7))
                Spacer()
                Button(action: onToggleTracking) {
                    Label(isTracking ? "Tracking" : "Track on Lock Screen", systemImage: "lock.fill")
                        .font(.caption.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(IlliniColor.orange)
            }
        }
        .padding()
        .background(IlliniColor.navy)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}

private struct InfoColumn: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.6))
            Text(value).font(.caption.bold()).foregroundStyle(.white)
        }
    }
}
