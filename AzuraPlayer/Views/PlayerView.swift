import SwiftUI
import AVKit

struct PlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var metadata = MetadataService.shared
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @State private var showSleepTimerDialog = false

    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var albumArtSize: CGFloat { isRegularWidth ? 400 : 290 }
    private var playButtonSize: CGFloat { isRegularWidth ? 100 : 75 }
    private var controlButtonSize: CGFloat { isRegularWidth ? 65 : 50 }
    private var horizontalPadding: CGFloat { isRegularWidth ? 80 : 60 }
    private var bottomPadding: CGFloat { isRegularWidth ? 60 : 50 }
    private func controlRowPadding(availableWidth: CGFloat) -> CGFloat {
        min(horizontalPadding, max(16, (availableWidth - 3 * controlButtonSize) / 4))
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 15) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 40, height: 5)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)

            Spacer()

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
            .frame(width: albumArtSize, height: albumArtSize)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
            .padding(.bottom, 20)

            VStack(spacing: 10) {
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

            Spacer()

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle().fill(accentColor).frame(width: playButtonSize, height: playButtonSize)
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: isRegularWidth ? 42 : 32))
                        .foregroundStyle(.white)
                }
                .shadow(color: accentColor.opacity(0.4), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .padding(.bottom, isRegularWidth ? 55 : 32)

            // AirPlay | Sleep Timer | Stop
            GeometryReader { geo in
                HStack {
                    ZStack {
                        Circle()
                            .fill(player.isAirPlayActive
                                  ? accentColor.opacity(0.2)
                                  : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                            .frame(width: controlButtonSize, height: controlButtonSize)
                        AirPlayButton(tintColor: UIColor(accentColor), activeTintColor: UIColor(accentColor))
                            .frame(width: isRegularWidth ? 36 : 28, height: isRegularWidth ? 36 : 28)
                    }

                    Spacer()

                    sleepTimerButton

                    Spacer()

                    Button {
                        player.stop()
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                                .frame(width: controlButtonSize, height: controlButtonSize)
                            Image(systemName: "stop.fill")
                                .font(.system(size: isRegularWidth ? 26 : 20))
                                .foregroundStyle(accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, controlRowPadding(availableWidth: geo.size.width))
            }
            .frame(height: controlButtonSize)
            .padding(.bottom, bottomPadding)
        }
        .background(Color(UIColor.systemBackground))
        .ignoresSafeArea(edges: .bottom)
        .onAppear { player.updateAirPlayState() }
        .confirmationDialog(
            tr("Sleep Timer", "Sleep Timer"),
            isPresented: $showSleepTimerDialog,
            titleVisibility: .visible
        ) {
            if player.sleepTimerEnd != nil {
                Button(tr("Cancel Timer", "Timer abbrechen"), role: .destructive) {
                    player.cancelSleepTimer()
                }
            }
            Button("15 \(tr("min", "Min"))") { player.setSleepTimer(minutes: 15) }
            Button("30 \(tr("min", "Min"))") { player.setSleepTimer(minutes: 30) }
            Button("45 \(tr("min", "Min"))") { player.setSleepTimer(minutes: 45) }
            Button("1 \(tr("hour", "Std"))") { player.setSleepTimer(minutes: 60) }
            Button("90 \(tr("min", "Min"))") { player.setSleepTimer(minutes: 90) }
            Button("2 \(tr("hours", "Std"))") { player.setSleepTimer(minutes: 120) }
            Button(tr("Cancel", "Abbrechen"), role: .cancel) {}
        }
    }

    @ViewBuilder
    private var sleepTimerButton: some View {
        Button {
            showSleepTimerDialog = true
        } label: {
            ZStack {
                Circle()
                    .fill(player.sleepTimerEnd != nil
                          ? accentColor.opacity(0.15)
                          : Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.15))
                    .frame(width: controlButtonSize, height: controlButtonSize)
                if let end = player.sleepTimerEnd {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let remaining = max(0, Int(end.timeIntervalSinceNow))
                        let mins = remaining / 60
                        let secs = remaining % 60
                        Text(String(format: "%d:%02d", mins, secs))
                            .font(.system(size: isRegularWidth ? 13 : 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(accentColor)
                    }
                } else {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: isRegularWidth ? 26 : 20))
                        .foregroundStyle(accentColor)
                }
            }
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
