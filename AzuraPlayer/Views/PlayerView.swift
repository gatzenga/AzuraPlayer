import SwiftUI

struct PlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var metadata = MetadataService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        VStack(spacing: 30) {
            // Griff & Schließen
            VStack(spacing: 15) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 10)

            Spacer().frame(height: 10)

            // Cover
            ZStack {
                if let station = player.currentStation,
                   station.showSongArt,
                   let artURL = metadata.currentTrack?.art,
                   let url = URL(string: artURL) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else if let data = station.customImageData, let uiImg = UIImage(data: data) {
                            Image(uiImage: uiImg).resizable().scaledToFill()
                        } else {
                            placeholder
                        }
                    }
                } else if let data = player.currentStation?.customImageData,
                          let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)

            // Infos
            VStack(spacing: 10) {
                Text(player.currentStation?.displayName ?? "Radio")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                // Status Anzeige (Verbinde vs. Live)
                if player.isBuffering {
                    Label("Verbinde...", systemImage: "wifi.exclamationmark")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                } else if player.isPlaying {
                    // NEU: Grünes Live-Symbol bei stabiler Verbindung
                    Label("Live • Verbunden", systemImage: "antenna.radiowaves.left.and.right")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .clipShape(Capsule())
                }

                if metadata.isLive {
                    Text("Live Übertragung")
                        .font(.caption)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.red.opacity(0.2))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }

                Text(metadata.currentTrack?.title ?? "Titel unbekannt")
                    .font(.title2).bold().multilineTextAlignment(.center).lineLimit(2)
                    .padding(.horizontal, 20)

                Text(metadata.currentTrack?.artist ?? "Künstler unbekannt")
                    .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(1)
                    .padding(.horizontal, 20)
            }

            Spacer()

            // Controls
            HStack(spacing: 60) {
                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(accentBlue).frame(width: 75, height: 75)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: accentBlue.opacity(0.4), radius: 10, y: 5)
                }

                Button {
                    player.stop()
                    dismiss()
                } label: {
                    ZStack {
                        Circle().fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15)).frame(width: 50, height: 50)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 20)).foregroundStyle(.primary)
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea()
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1)
            Image(systemName: "music.note.house")
                .font(.system(size: 80)).foregroundStyle(.gray.opacity(0.5))
        }
    }
}
