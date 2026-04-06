import SwiftUI

@main
struct AzuraPlayerWatchApp: App {
    @StateObject private var store = WatchStationStore()
    @StateObject private var player = WatchNowPlayingManager()

    var body: some Scene {
        WindowGroup {
            StationListView()
                .environmentObject(store)
                .environmentObject(player)
        }
    }
}
