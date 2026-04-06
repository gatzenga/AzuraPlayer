import SwiftUI
import WatchKit

struct NowPlayingView: View {
    @EnvironmentObject var player: WatchNowPlayingManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 8) {

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
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 12))
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

            // Lautstärke (Digital Crown → System-Volume via WKInterfaceVolumeControl)
            VolumeControl()
                .frame(height: 12)

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
        .padding(.vertical, 6)
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

// MARK: - System Volume Control (WKInterfaceVolumeControl → Digital Crown)

private struct VolumeControl: WKInterfaceObjectRepresentable {
    typealias WKInterfaceObjectType = WKInterfaceVolumeControl

    func makeWKInterfaceObject(context: Context) -> WKInterfaceVolumeControl {
        WKInterfaceVolumeControl(origin: .local)
    }

    func updateWKInterfaceObject(_ control: WKInterfaceVolumeControl, context: Context) {
        control.focus()
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
                // Animation via Modifier statt withAnimation im Task –
                // läuft im SwiftUI-Render-Pass, zuverlässig auf watchOS
                .animation(
                    isReturning
                        ? .linear(duration: 0.3)
                        : .linear(duration: scrollDuration),
                    value: offset
                )
        }
        .frame(maxWidth: .infinity)
        .clipped()

        // Containerbreite messen (background = selbe Grösse wie Host-View)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ContainerWidthKey.self, value: geo.size.width)
            }
        )

        // Textbreite messen (nahezu-unsichtbare Kopie mit fixedSize = natürliche Breite)
        .background(alignment: .leading) {
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .opacity(0.001)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: TextWidthKey.self, value: geo.size.width)
                    }
                )
        }

        .onPreferenceChange(ContainerWidthKey.self) { w in
            guard w > 0, w != containerWidth else { return }
            containerWidth = w
            restart()
        }
        .onPreferenceChange(TextWidthKey.self) { w in
            guard w > 0, w != textWidth else { return }
            textWidth = w
            restart()
        }
        .onChange(of: text) { _, _ in
            textWidth = 0
            restart()
        }
        .onAppear {
            // Safety: nochmals restart nach erstem Layout-Pass
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                restart()
            }
        }
        .onDisappear { scrollTask?.cancel() }
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

private struct ContainerWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
