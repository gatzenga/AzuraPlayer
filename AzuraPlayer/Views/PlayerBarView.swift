import SwiftUI

struct PlayerBarView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var metadata = MetadataService.shared
    @AppStorage("themeColor") private var themeColorName = "blue"
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var accentColor: Color { AppTheme.color(for: themeColorName) }
    private var isRegular: Bool { hSizeClass == .regular }

    // iPad bekommt eine kompakte, aber merklich größere Variante
    private var coverSize: CGFloat { isRegular ? 56 : 40 }
    private var coverCorner: CGFloat { isRegular ? 10 : 8 }
    private var vPad: CGFloat { isRegular ? 10 : 8 }
    private var hPad: CGFloat { isRegular ? 18 : 16 }
    private var hStackSpacing: CGFloat { isRegular ? 14 : 12 }
    private var controlSize: CGFloat { isRegular ? 36 : 30 }
    private var playSize: CGFloat { isRegular ? 44 : 36 }
    private var titleFont: Font { isRegular ? .body : .subheadline }
    private var subtitleFont: Font { isRegular ? .footnote : .caption }
    private var playIconFont: Font { isRegular ? .title3 : .body }
    private var controlIconFont: Font { isRegular ? .title3 : .callout }

    var body: some View {
        HStack(spacing: hStackSpacing) {
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
            .frame(width: coverSize, height: coverSize)
            .clipShape(RoundedRectangle(cornerRadius: coverCorner))
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

            VStack(alignment: .leading, spacing: 2) {
                if player.isBuffering {
                    Text(tr("Connecting...", "Verbinde..."))
                        .font(titleFont).bold()
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                } else {
                    Text(metadata.currentTrack?.title ?? (player.isPlaying ? tr("Live Stream", "Live Stream") : tr("Paused", "Pausiert")))
                        .font(titleFont).bold()
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(metadata.currentTrack?.artist ?? player.currentStation?.displayName ?? "")
                    .font(subtitleFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(playIconFont)
                    .foregroundStyle(.white)
                    .frame(width: playSize, height: playSize)
                    .background(accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Button {
                player.stop()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(controlIconFont)
                    .foregroundStyle(accentColor)
                    .frame(width: controlSize, height: controlSize)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, hPad)
        .padding(.vertical, vPad)
        .contentShape(Rectangle())
        .modifier(LiquidGlassBar())
    }
}

private struct LiquidGlassBar: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: Capsule(style: .continuous))
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        }
    }
}
