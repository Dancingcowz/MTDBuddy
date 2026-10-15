import SwiftUI

/// Route short name in MTD's official colors (darkened automatically for contrast).
struct RouteBadge: View {
    let shortName: String
    let colorHex: String
    let textColorHex: String

    var body: some View {
        Text(shortName)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(MTDRouteColor.display(hex: colorHex))
            .foregroundStyle(Color(hex: textColorHex))
            .clipShape(Capsule())
    }
}

struct BoardStatusLabel: View {
    let status: BoardStatus

    var body: some View {
        Label(status.label, systemImage: status.systemImage)
            .labelStyle(.titleAndIcon)
            .font(.caption.bold())
            .foregroundStyle(status.color)
    }
}
