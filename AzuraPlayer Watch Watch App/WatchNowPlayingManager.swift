import Foundation
import AVFoundation
import MediaPlayer
import Combine

class WatchNowPlayingManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentStation: RadioStation?
    @Published var songTitle: String = ""
    @Published var artistName: String = ""
    @Published var artworkURL: String?

    private var player: AVPlayer?
    private var pollTask: Task<Void, Never>?
    private var sessionActivated = false

    override init() {
        super.init()
        configureAudioCategory()
        setupRemoteControls()
        setupInterruptionHandling()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio Session

    // Schritt 1: Kategorie einmalig bei init setzen (synchron, OK auf watchOS)
    private func configureAudioCategory() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: []
            )
        } catch {
            print("Watch audio category error: \(error)")
        }
    }

    // Schritt 2: Session ASYNCHRON aktivieren (Apple WWDC19-716: Pflicht auf watchOS)
    // watchOS zeigt bei Bedarf automatisch den Audio-Route-Picker (AirPods etc.)
    private func activateAndPlay(station: RadioStation, url: URL) {
        if sessionActivated {
            startPlayback(station: station, url: url)
            return
        }

        AVAudioSession.sharedInstance().activate(options: []) { [weak self] success, error in
            guard let self else { return }
            if let error = error {
                print("Watch session activation error: \(error)")
                return
            }
            guard success else { return }

            DispatchQueue.main.async {
                self.sessionActivated = true
                self.startPlayback(station: station, url: url)
            }
        }
    }

    private func startPlayback(station: RadioStation, url: URL) {
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.play()

        isPlaying = true
        startPolling(station: station)
        updateNowPlaying()
    }

    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            sessionActivated = false
        } else if type == .ended {
            if let station = currentStation {
                play(station: station)
            }
        }
    }

    // MARK: - Playback

    func play(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        player?.replaceCurrentItem(with: nil)
        player = nil

        currentStation = station
        activateAndPlay(station: station, url: url)
    }

    func stop() {
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlaying = false
        currentStation = nil
        songTitle = ""
        artistName = ""
        artworkURL = nil
        pollTask?.cancel()
        pollTask = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func pause() {
        player?.replaceCurrentItem(with: nil)
        player = nil
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if let station = currentStation {
            play(station: station)
        }
    }

    // MARK: - Remote Controls (AirPods / Kopfhörer / Sperr-Screen)

    private func setupRemoteControls() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            guard let self, let station = self.currentStation else { return .commandFailed }
            self.play(station: station)
            return .success
        }

        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        cc.nextTrackCommand.isEnabled = false
        cc.previousTrackCommand.isEnabled = false
        cc.skipForwardCommand.isEnabled = false
        cc.skipBackwardCommand.isEnabled = false
    }

    // MARK: - Metadata Polling

    private func startPolling(station: RadioStation) {
        pollTask?.cancel()
        guard !station.apiURL.isEmpty else { return }

        pollTask = Task {
            while !Task.isCancelled {
                await fetchNowPlaying(station: station)
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func fetchNowPlaying(station: RadioStation) async {
        guard let url = URL(string: station.apiURL) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        guard let response = try? JSONDecoder().decode(NowPlayingResponse.self, from: data) else { return }

        await MainActor.run {
            if let song = response.nowPlaying?.song {
                self.songTitle = song.title
                self.artistName = song.artist
                self.artworkURL = song.art
            }
            self.updateNowPlaying()
        }
    }

    // MARK: - Now Playing Info

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = songTitle.isEmpty ? (currentStation?.displayName ?? "") : songTitle
        info[MPMediaItemPropertyArtist] = artistName.isEmpty ? (currentStation?.displayName ?? "") : artistName
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
