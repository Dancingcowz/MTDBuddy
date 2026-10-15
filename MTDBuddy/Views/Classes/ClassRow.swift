import SwiftUI

struct ClassRow: View {
    let title: String
    let nextStart: Date
    let location: String?
    @Binding var config: BusClassConfig
    @EnvironmentObject private var catalog: CatalogStore
    @State private var showStopPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.subheadline.bold())
                    Text(nextStart.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("", selection: $config.isBusClass) {
                    Text("Bus").tag(true)
                    Text("Walk").tag(false)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if config.isBusClass {
                HStack {
                    Button {
                        showStopPicker = true
                    } label: {
                        Label(config.stopId.map { catalog.stopName($0) } ?? "Choose stop near building", systemImage: "mappin.circle")
                            .font(.caption)
                    }
                    Spacer()
                    Stepper("Walk: \(config.walkMinutes) min", value: $config.walkMinutes, in: 1...30)
                        .font(.caption)
                        .fixedSize()
                }
            }
        }
        .sheet(isPresented: $showStopPicker) {
            StopPickerView(prefill: location ?? "") { stop in
                config.stopId = stop.stopId
            }
        }
    }
}
