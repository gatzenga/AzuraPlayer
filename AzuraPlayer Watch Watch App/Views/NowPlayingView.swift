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

            // Titel · Künstler – Laufschrift wenn zu lang
            let title = player.songTitle.isEmpty ? "Unbekannt" : player.songTitle
            let artist = player.artistName
            let combined = artist.isEmpty ? title : "\(title) · \(artist)"

            MarqueeText(text: combined, font: .footnote.weight(.medium))
                .frame(maxWidth: .infinity)
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

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { textWidth = geo.size.width }
                    .onChange(of: text) { _, _ in textWidth = geo.size.width }
            })
            .offset(x: offset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(GeometryReader { geo in
                Color.clear.onAppear {
                    containerWidth = geo.size.width
                    restart()
                }
            })
            .onChange(of: text) { _, _ in restart() }
            .onDisappear { scrollTask?.cancel() }
    }

    private func restart() {
        scrollTask?.cancel()
        offset = 0
        // Kurze Verzögerung damit textWidth gemessen ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard textWidth > containerWidth, containerWidth > 0 else { return }
            let dist = textWidth - containerWidth + 12
            let dur = Double(dist) / 28.0
            scrollTask = Task { @MainActor in
                do {
                    while true {
                        try await Task.sleep(for: .seconds(2.0))   // Pause am Anfang
                        withAnimation(.linear(duration: dur)) { offset = -dist }
                        try await Task.sleep(for: .seconds(dur + 1.5)) // Pause am Ende
                        withAnimation(.linear(duration: 0.25)) { offset = 0 }
                    }
                } catch { /* Task abgebrochen (Text geändert oder View weg) */ }
            }
        }
    }
}
