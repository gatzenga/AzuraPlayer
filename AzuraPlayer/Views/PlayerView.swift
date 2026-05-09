import SwiftUI
import AVKit

private final class PlayerPaletteResult: NSObject {
    let primary: UIColor
    let secondary: UIColor?
    init(_ primary: UIColor, _ secondary: UIColor?) {
        self.primary = primary
        self.secondary = secondary
    }
}

struct PlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var metadata = MetadataService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showSleepTimerDialog = false

    @State private var rawPrimary: UIColor? = nil
    @State private var rawSecondary: UIColor? = nil
    @State private var playerBgPrimary: Color = Color(UIColor.systemBackground)
    @State private var playerBgSecondary: Color = Color(UIColor.systemBackground)

    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private func artSize(_ h: CGFloat) -> CGFloat { isPad ? min(380, max(240, h * 0.42)) : 290 }
    private func playButtonSize(_ h: CGFloat) -> CGFloat { isPad ? min(96, max(72, h * 0.11)) : 75 }
    private func controlSize(_ h: CGFloat) -> CGFloat { isPad ? min(56, max(44, h * 0.065)) : 50 }
    private func vPad(_ h: CGFloat, large: CGFloat, small: CGFloat) -> CGFloat {
        guard isPad else { return small }
        return h < 760 ? max(small * 0.6, large * 0.5) : large
    }

    private static let paletteCache: NSCache<NSString, PlayerPaletteResult> = {
        let c = NSCache<NSString, PlayerPaletteResult>()
        c.countLimit = 200
        return c
    }()

    private var coverIdentifier: String {
        if let station = player.currentStation,
           station.showSongArt,
           let art = metadata.currentTrack?.art {
            return art
        }
        return player.currentStation?.id.uuidString ?? "none"
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let h = geo.size.height
                let art = artSize(h)
                let play = playButtonSize(h)
                let ctrl = controlSize(h)
            VStack(spacing: 0) {
                Spacer(minLength: 0)

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
                .frame(width: art, height: art)
                .clipShape(RoundedRectangle(cornerRadius: isPad ? 22 : 24))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 15)
                .padding(.bottom, vPad(h, large: 20, small: 20))

                VStack(spacing: isPad ? 6 : 10) {
                    Text(player.currentStation?.displayName ?? "Radio")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if player.isBuffering {
                        Label(tr("Connecting...", "Verbinde..."), systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    } else if player.isPlaying {
                        Label("Live", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                    } else {
                        Label(tr("Paused", "Pausiert"), systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    if metadata.isLive {
                        Text(tr("Live Broadcast", "Live Übertragung"))
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }

                    Text(metadata.currentTrack?.title ?? tr("Unknown Title", "Titel unbekannt"))
                        .font(.title2).bold().multilineTextAlignment(.center).lineLimit(2)
                        .padding(.horizontal, 20)

                    Text(metadata.currentTrack?.artist ?? tr("Unknown Artist", "Künstler unbekannt"))
                        .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(1)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 0)

                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle().fill(accentColor).frame(width: play, height: play)
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isPad ? 34 : 30))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .padding(.bottom, vPad(h, large: 36, small: 32))

                HStack(spacing: isPad ? 80 : 60) {
                    sleepTimerButton(ctrl: ctrl)
                    stopButton(ctrl: ctrl)
                }
                .padding(.bottom, vPad(h, large: 32, small: 50))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background {
                LinearGradient(
                    stops: [
                        .init(color: playerBgPrimary, location: 0.0),
                        .init(color: playerBgPrimary, location: 0.45),
                        .init(color: playerBgSecondary, location: 0.75),
                        .init(color: playerBgSecondary, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .ignoresSafeArea(edges: .bottom)
            .sheet(isPresented: $showSleepTimerDialog) {
                SleepTimerPanel()
                    .presentationSizing(.page)
                    .presentationCornerRadius(24)
                    .presentationDragIndicator(.visible)
                    .tint(accentColor)
            }
            } // GeometryReader
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    AirPlayButton(tintColor: .label, activeTintColor: UIColor(accentColor))
                        .frame(width: 34, height: 34)
                }
            }
            .onAppear { player.updateAirPlayState() }
            .task(id: coverIdentifier) { await updatePlayerBackground() }
            .onChange(of: colorScheme) { _, _ in
                guard let raw = rawPrimary else { return }
                playerBgPrimary = adaptedColor(raw, asSecondary: false)
                playerBgSecondary = adaptedColor(rawSecondary ?? raw, asSecondary: true)
            }
        }
    }

    @ViewBuilder
    private func sleepTimerButton(ctrl: CGFloat) -> some View {
        Button {
            showSleepTimerDialog = true
        } label: {
            if let end = player.sleepTimerEnd {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let remaining = max(0, Int(end.timeIntervalSinceNow))
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: isPad ? 13 : 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(accentColor)
                }
                .frame(width: ctrl, height: ctrl)
            } else {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: isPad ? 22 : 20))
                    .foregroundStyle(.secondary)
                    .frame(width: ctrl, height: ctrl)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func stopButton(ctrl: CGFloat) -> some View {
        Button {
            player.stop()
            dismiss()
        } label: {
            Image(systemName: "stop.fill")
                .font(.system(size: isPad ? 22 : 20))
                .foregroundStyle(.primary)
                .frame(width: ctrl, height: ctrl)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var placeholder: some View {
        ZStack {
            Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1)
            Image(systemName: "music.note.house")
                .font(.system(size: 80)).foregroundStyle(.gray.opacity(0.5))
        }
    }

    private func updatePlayerBackground() async {
        let key = coverIdentifier

        if let hit = Self.paletteCache.object(forKey: key as NSString) {
            rawPrimary = hit.primary
            rawSecondary = hit.secondary
            withAnimation(.easeInOut(duration: 0.6)) {
                playerBgPrimary = adaptedColor(hit.primary, asSecondary: false)
                playerBgSecondary = adaptedColor(hit.secondary ?? hit.primary, asSecondary: true)
            }
            return
        }

        let image = await loadCoverImage()
        guard !Task.isCancelled else { return }

        guard let img = image else {
            rawPrimary = nil
            rawSecondary = nil
            withAnimation(.easeInOut(duration: 0.5)) {
                playerBgPrimary = Color(UIColor.systemBackground)
                playerBgSecondary = Color(UIColor.systemBackground)
            }
            return
        }

        let (primary, secondary) = img.extractPlayerPalette()
        guard !Task.isCancelled else { return }
        Self.paletteCache.setObject(PlayerPaletteResult(primary, secondary), forKey: key as NSString)
        rawPrimary = primary
        rawSecondary = secondary
        withAnimation(.easeInOut(duration: 0.6)) {
            playerBgPrimary = adaptedColor(primary, asSecondary: false)
            playerBgSecondary = adaptedColor(secondary ?? primary, asSecondary: true)
        }
    }

    private func loadCoverImage() async -> UIImage? {
        if let station = player.currentStation,
           station.showSongArt,
           let artURLString = metadata.currentTrack?.art,
           let url = URL(string: artURLString),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let img = UIImage(data: data) {
            return img
        }
        if let data = player.currentStation?.customImageData {
            return UIImage(data: data)
        }
        return nil
    }

    private func adaptedColor(_ uiColor: UIColor, asSecondary: Bool) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
        let factor: CGFloat = asSecondary ? 0.88 : 1.0
        if colorScheme == .dark {
            return Color(UIColor(
                hue: h,
                saturation: min(s * 1.2 * factor, 0.90),
                brightness: min(max(v, 0.35) * 0.82, 0.72),
                alpha: 1
            ))
        } else {
            return Color(UIColor(
                hue: h,
                saturation: min(s * 0.82 * factor, 0.78),
                brightness: min(v * 0.45 + 0.58, 0.96),
                alpha: 1
            ))
        }
    }
}

private struct SleepTimerPanel: View {
    @ObservedObject private var player = AudioPlayerService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if player.sleepTimerEnd != nil {
                    Section {
                        Button(role: .destructive) {
                            player.cancelSleepTimer(); dismiss()
                        } label: {
                            Text(tr("Cancel Timer", "Timer abbrechen"))
                        }
                    }
                }
                Section {
                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                        Button {
                            player.setSleepTimer(minutes: minutes); dismiss()
                        } label: {
                            Text(rowLabel(for: minutes))
                                .foregroundStyle(Color.primary)
                        }
                    }
                }
            }
            .navigationTitle(tr("Sleep Timer", "Sleep Timer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Text(tr("Done", "Fertig")).bold()
                    }
                }
            }
        }
    }

    private func rowLabel(for minutes: Int) -> String {
        switch minutes {
        case 60:  return "1 \(tr("hour", "Std"))"
        case 120: return "2 \(tr("hours", "Std"))"
        default:  return "\(minutes) \(tr("min", "Min"))"
        }
    }
}

struct AirPlayButton: UIViewRepresentable {
    var tintColor: UIColor = .label
    var activeTintColor: UIColor = .systemBlue

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = tintColor
        picker.activeTintColor = activeTintColor
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
    }
}

private extension UIImage {
    func extractPlayerPalette() -> (UIColor, UIColor?) {
        let totalBuckets = 14

        let side = 32
        let totalPixels = side * side
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let small = renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = small.cgImage else { return (.systemGray, nil) }

        var pixels = [UInt8](repeating: 0, count: totalPixels * 4)
        guard let ctx = CGContext(
            data: &pixels, width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return (.systemGray, nil) }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var rSum = [CGFloat](repeating: 0, count: totalBuckets)
        var gSum = [CGFloat](repeating: 0, count: totalBuckets)
        var bSum = [CGFloat](repeating: 0, count: totalBuckets)
        var counts = [Int](repeating: 0, count: totalBuckets)

        for i in stride(from: 0, to: pixels.count, by: 4) {
            let r = CGFloat(pixels[i]) / 255
            let g = CGFloat(pixels[i+1]) / 255
            let b = CGFloat(pixels[i+2]) / 255

            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            UIColor(red: r, green: g, blue: b, alpha: 1).getHue(&h, saturation: &s, brightness: &v, alpha: &a)

            let bucket: Int
            if v < 0.20 {
                bucket = 12
            } else if v > 0.85, s < 0.12 {
                bucket = 13
            } else if s >= 0.15 {
                bucket = min(Int(h * 12), 11)
            } else {
                continue
            }
            rSum[bucket] += r; gSum[bucket] += g; bSum[bucket] += b
            counts[bucket] += 1
        }

        func bucketColor(at idx: Int) -> UIColor {
            let n = CGFloat(counts[idx])
            return UIColor(red: rSum[idx]/n, green: gSum[idx]/n, blue: bSum[idx]/n, alpha: 1)
        }

        let chromaticSorted = (0..<12).filter { counts[$0] > 0 }.sorted { counts[$0] > counts[$1] }

        var primary: UIColor
        var secondary: UIColor? = nil

        if let primaryIdx = chromaticSorted.first {
            let chromaticColor = bucketColor(at: primaryIdx)
            let chromaticCount = counts[primaryIdx]
            let minSecondaryCount = max(3, chromaticCount / 10)

            for candidateIdx in chromaticSorted.dropFirst() {
                let diff = abs(candidateIdx - primaryIdx)
                if min(diff, 12 - diff) >= 2, counts[candidateIdx] >= minSecondaryCount {
                    secondary = bucketColor(at: candidateIdx)
                    break
                }
            }

            if secondary != nil {
                primary = chromaticColor
            } else {
                let darkCount = counts[12]
                let lightCount = counts[13]
                let neutralIdx = darkCount >= lightCount ? 12 : 13
                let neutralCount = max(darkCount, lightCount)
                if neutralCount > 0 {
                    if neutralCount > chromaticCount {
                        primary = bucketColor(at: neutralIdx)
                        secondary = chromaticColor
                    } else {
                        primary = chromaticColor
                        secondary = bucketColor(at: neutralIdx)
                    }
                } else {
                    primary = chromaticColor
                }
            }
        } else {
            let darkCount = counts[12]
            let lightCount = counts[13]
            if darkCount >= lightCount {
                primary = darkCount > 0 ? bucketColor(at: 12) : .systemGray
                secondary = lightCount > 0 ? bucketColor(at: 13) : nil
            } else {
                primary = bucketColor(at: 13)
                secondary = darkCount > 0 ? bucketColor(at: 12) : nil
            }
        }

        if secondary == nil {
            var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0, a: CGFloat = 0
            primary.getHue(&h, saturation: &s, brightness: &v, alpha: &a)
            secondary = UIColor(
                hue: h,
                saturation: min(s * 0.8, 1.0),
                brightness: max(v * 0.45, 0.10),
                alpha: 1
            )
        }

        return (primary, secondary)
    }
}
