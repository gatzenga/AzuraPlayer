import SwiftUI

struct StationListView: View {
    @EnvironmentObject var store: WatchStationStore
    @EnvironmentObject var player: WatchNowPlayingManager

    @State private var showNowPlaying = false
    @State private var pulse = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.stations) { station in
                    StationRowView(station: station)
                }
            }
            .navigationTitle("Sender")
            .navigationDestination(isPresented: $showNowPlaying) {
                NowPlayingView()
            }
            .overlay {
                if store.stations.isEmpty {
                    ContentUnavailableView(
                        "Keine Sender",
                        systemImage: "radio",
                        description: Text("Sender in der iPhone-App hinzufügen")
                    )
                }
            }
            // Floating Now Playing Button
            .overlay(alignment: .bottomTrailing) {
                if player.currentStation != nil {
                    Button {
                        showNowPlaying = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 40, height: 40)

                            Circle()
                                .fill(Color.blue.opacity(0.55))
                                .frame(width: 40, height: 40)
                                .scaleEffect(pulse ? 1.12 : 1.0)
                                .animation(
                                    player.isPlaying
                                        ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
                                        : .default,
                                    value: pulse
                                )

                            Image(systemName: player.isPlaying ? "waveform" : "pause.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 4)
                    .padding(.trailing, 4)
                    .onAppear { pulse = player.isPlaying }
                    .onChange(of: player.isPlaying) { _, playing in
                        pulse = playing
                    }
                }
            }
        }
    }
}
