import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: WatchNowPlayingManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Cover
                Group {
                    if let data = player.currentStation?.customImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "radio")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Sendername
                Text(player.currentStation?.displayName ?? "")
                    .font(.footnote.weight(.bold))
                    .lineLimit(1)

                // Song
                if !player.songTitle.isEmpty {
                    Text(player.songTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                // Steuerung
                HStack(spacing: 20) {
                    Button {
                        if player.isPlaying {
                            player.stop()
                        } else if let station = player.currentStation {
                            player.play(station: station)
                        }
                    } label: {
                        Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(player.isPlaying ? Color.red : Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
    }
}
