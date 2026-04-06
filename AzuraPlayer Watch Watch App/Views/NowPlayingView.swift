import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var player: WatchNowPlayingManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 10) {

            // Cover
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

            // Titel · Künstler
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
        // Kein focusable() – watchOS leitet Crown-Rotation automatisch
        // ans System-Volume wenn longFormAudio-Session aktiv ist.
        // focusable() würde Crown-Druck (= Zurück) abfangen und den Stream unterbrechen.
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
    @State private var scrollDuration: Double = 3.0
    @State private var isReturning: Bool = false
    @State private var scrollTask: Task<Void, Never>?

    private var needsScroll: Bool {
        textWidth > 0 && containerWidth > 0 && textWidth > containerWidth
    }

    var body: some View {
        ZStack(alignment: needsScroll ? .leading : .center) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .offset(x: needsScroll ? offset : 0)
                // .animation auf dem View statt withAnimation im Task –
                // zuverlässiger auf watchOS da Teil des SwiftUI-Render-Passes
                .animation(
                    isReturning
                        ? .linear(duration: 0.3)
                        : .linear(duration: scrollDuration),
                    value: offset
                )
        }
        .frame(maxWidth: .infinity)
        .clipped()

        // Containerbreite: GeometryReader im background
        // (background ändert die Layout-Grösse des Elternviews nicht)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { setContainer(geo.size.width) }
                    .onChange(of: geo.size.width) { _, w in setContainer(w) }
            }
        )

        // Textbreite: nahezu-unsichtbare Kopie (opacity statt hidden –
        // watchOS berechnet Geometrie für hidden Views möglicherweise nicht)
        .background(alignment: .leading) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .opacity(0.001)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { setText(geo.size.width) }
                            .onChange(of: geo.size.width) { _, w in setText(w) }
                    }
                )
        }

        .onChange(of: text) { _, _ in restart() }
        .onDisappear { scrollTask?.cancel() }
    }

    private func setContainer(_ w: CGFloat) {
        guard w > 0, w != containerWidth else { return }
        containerWidth = w
        restart()
    }

    private func setText(_ w: CGFloat) {
        guard w > 0, w != textWidth else { return }
        textWidth = w
        restart()
    }

    private func restart() {
        scrollTask?.cancel()
        offset = 0
        isReturning = false
        guard textWidth > containerWidth, textWidth > 0, containerWidth > 0 else { return }

        let dist = textWidth - containerWidth + 10
        scrollDuration = max(Double(dist) / 28.0, 1.5)
        let dur = scrollDuration

        scrollTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(2))
                while !Task.isCancelled {
                    // Offset ändern ohne withAnimation –
                    // .animation(_:value:) auf dem View übernimmt die Animation
                    isReturning = false
                    offset = -dist
                    try await Task.sleep(for: .seconds(dur + 1.5))
                    guard !Task.isCancelled else { break }
                    isReturning = true
                    offset = 0
                    try await Task.sleep(for: .seconds(0.3 + 2.0))
                }
            } catch {}
        }
    }
}
