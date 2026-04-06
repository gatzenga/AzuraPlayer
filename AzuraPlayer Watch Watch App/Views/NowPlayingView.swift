import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: WatchNowPlayingManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 10) {

            // Cover
            Group {
                if let urlString = player.artworkURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            placeholderIcon
                        }
                    }
                } else {
                    placeholderIcon
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 4)

            // Sendername
            Text(player.currentStation?.displayName ?? "")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            // Titel · Künstler in einer Zeile
            let title = player.songTitle.isEmpty ? "Unbekannt" : player.songTitle
            let artist = player.artistName
            Text(artist.isEmpty ? title : "\(title) · \(artist)")
                .font(.footnote.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            // Controls
            HStack(spacing: 20) {
                // Pause / Play
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                // Stop
                Button {
                    player.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .navigationTitle("")
    }

    private var placeholderIcon: some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: "music.note.house")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
