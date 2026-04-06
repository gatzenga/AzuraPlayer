import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: WatchNowPlayingManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 10) {

            // Cover: Song-Art wenn gewünscht, sonst Custom-Bild, sonst Platzhalter
            Group {
                if let station = player.currentStation,
                   station.showSongArt,
                   let urlString = player.artworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().scaledToFill()
                        } else {
                            customOrPlaceholder(station)
                        }
                    }
                } else if let station = player.currentStation {
                    customOrPlaceholder(station)
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

            // Titel · Künstler – zentriert wenn passend, Laufschrift wenn zu lang
            let title = player.songTitle.isEmpty ? "Unbekannt" : player.songTitle
            let artist = player.artistName
            let combined = artist.isEmpty ? title : "\(title) · \(artist)"

            MarqueeText(text: combined, font: .footnote.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            // Controls
            HStack(spacing: 20) {
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

    @ViewBuilder
    private func customOrPlaceholder(_ station: RadioStation) -> some View {
        if let data = station.customImageData, let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg).resizable().scaledToFill()
        } else {
            placeholderIcon
        }
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

// MARK: - Marquee Text

private struct MarqueeText: View {
    let text: String
    let font: Font

    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var scrollTask: Task<Void, Never>?

    private var fits: Bool {
        textWidth > 0 && containerWidth > 0 && textWidth <= containerWidth
    }

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            // Textbreite messen
            .background(GeometryReader { geo in
                Color.clear.preference(key: MarqueeTextWidthKey.self, value: geo.size.width)
            })
            .offset(x: fits ? 0 : offset)
            .frame(maxWidth: .infinity, alignment: fits ? .center : .leading)
            .clipped()
            // Containerbreite messen
            .background(GeometryReader { geo in
                Color.clear.preference(key: MarqueeContainerWidthKey.self, value: geo.size.width)
            })
            .onPreferenceChange(MarqueeTextWidthKey.self) { w in
                guard w != textWidth else { return }
                textWidth = w
                restart()
            }
            .onPreferenceChange(MarqueeContainerWidthKey.self) { w in
                guard w != containerWidth else { return }
                containerWidth = w
                restart()
            }
            .onChange(of: text) { _, _ in restart() }
            .onDisappear { scrollTask?.cancel() }
    }

    private func restart() {
        scrollTask?.cancel()
        offset = 0
        guard textWidth > containerWidth, textWidth > 0, containerWidth > 0 else { return }
        let dist = textWidth - containerWidth + 10
        let dur = max(Double(dist) / 28.0, 1.0)
        scrollTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2.0))
                while true {
                    withAnimation(.linear(duration: dur)) { offset = -dist }
                    try await Task.sleep(for: .seconds(dur + 1.5))
                    withAnimation(.linear(duration: 0.3)) { offset = 0 }
                    try await Task.sleep(for: .seconds(2.0))
                }
            } catch {}
        }
    }
}

private struct MarqueeTextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct MarqueeContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
