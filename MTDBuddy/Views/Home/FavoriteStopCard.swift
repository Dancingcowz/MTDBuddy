import SwiftUI

struct FavoriteStopCard: View {
    let stopName: String
    let departures: [MTDDeparture]
    let error: Error?
    let statusFor: (MTDDeparture) -> BoardStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stopName).font(.subheadline.bold())

            if let error {
                Text((error as? MTDServiceError)?.errorDescription ?? error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if departures.isEmpty {
                Text("No upcoming departures").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(departures) { departure in
                    DepartureRow(departure: departure, status: statusFor(departure))
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DepartureRow: View {
    let departure: MTDDeparture
    var status: BoardStatus?

    var body: some View {
        HStack {
            RouteBadge(
                shortName: departure.route.routeShortName,
                colorHex: departure.route.routeColor,
                textColorHex: departure.route.routeTextColor
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(departure.headsign).font(.caption.bold()).lineLimit(1)
                Text(departure.isLive ? "Live" : "Scheduled")
                    .font(.caption2)
                    .foregroundStyle(departure.isLive ? .green : .secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(departure.expected.formatted(date: .omitted, time: .shortened))
                    .font(.caption.bold())
                if let status {
                    BoardStatusLabel(status: status)
                } else {
                    Text("\(max(0, departure.expected.minutesFromNow)) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
