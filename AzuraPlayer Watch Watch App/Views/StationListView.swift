import SwiftUI

struct StationListView: View {
    @EnvironmentObject var store: WatchStationStore
    @EnvironmentObject var player: WatchNowPlayingManager

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.stations) { station in
                    StationRowView(station: station)
                }
            }
            .navigationTitle("Sender")
            .overlay {
                if store.stations.isEmpty {
                    ContentUnavailableView(
                        "Keine Sender",
                        systemImage: "radio",
                        description: Text("Sender in der iPhone-App hinzufügen")
                    )
                }
            }
        }
    }
}
