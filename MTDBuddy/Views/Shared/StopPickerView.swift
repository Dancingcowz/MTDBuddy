import SwiftUI

/// Searchable stop picker used for the home stop (Settings) and each class's boarding stop
/// (Classes), prefilled with a search string when one is available (e.g. the event location).
struct StopPickerView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String
    let showCancelButton: Bool
    let onSelect: (MTDStop) -> Void

    init(prefill: String = "", showCancelButton: Bool = true, onSelect: @escaping (MTDStop) -> Void) {
        _searchText = State(initialValue: prefill)
        self.showCancelButton = showCancelButton
        self.onSelect = onSelect
    }

    private var filtered: [MTDStop] {
        guard !searchText.isEmpty else { return catalog.stops }
        return catalog.stops.filter { $0.stopName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { stop in
                Button {
                    onSelect(stop)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(stop.stopName).foregroundStyle(.primary)
                        Text(stop.code).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search stops")
            .navigationTitle("Choose a Stop")
            .toolbar {
                if showCancelButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
    }
}
