import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: WatchSessionManager

    var body: some View {
        VStack(spacing: 12) {
            if session.isConnected && !session.stationName.isEmpty {

                Text(session.stationName)
                    .font(.headline)
                    .lineLimit(1)

                Divider()

                Text(session.songTitle.isEmpty ? "–" : session.songTitle)
                    .font(.caption)
                    .bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(session.artist.isEmpty ? "–" : session.artist)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 20) {
                    Button {
                        session.sendCommand(session.isPlaying ? "pause" : "play")
                    } label: {
                        Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        session.sendCommand("stop")
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.gray)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

            } else {
                Spacer()
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("AzuraPlayer auf dem iPhone öffnen")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
        }
        .padding()
    }
}
