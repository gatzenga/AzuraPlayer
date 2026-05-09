import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var metadata = MetadataService.shared
    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        HStack(spacing: 14) {
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
                            Color.gray.opacity(0.3)
                        }
                    }
                } else if let data = player.currentStation?.customImageData,
                          let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg).resizable().scaledToFill()
                } else {
                    Color.gray.opacity(0.3)
                        .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            .overlay(alignment: .bottomTrailing) {
                if player.isBuffering || player.isPlaying {
                    Circle()
                        .fill(player.isBuffering ? Color.orange : Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if player.isBuffering {
                    Text(tr("Connecting...", "Verbinde..."))
                        .font(.subheadline).bold()
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(metadata.currentTrack?.title ?? (player.isPlaying ? tr("Live Stream", "Live Stream") : tr("Paused", "Pausiert")))
                        .font(.subheadline).bold()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(metadata.currentTrack?.artist ?? player.currentStation?.displayName ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accentColor)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .modifier(LiquidGlassBar())
    }
}

private struct LiquidGlassBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
    }
}
