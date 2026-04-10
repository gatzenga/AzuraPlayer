import AVFoundation
import MediaPlayer
import Combine
import UIKit

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentStation: RadioStation?
    @Published var sleepTimerEnd: Date? = nil
    @Published var isAirPlayActive: Bool = false
    @Published var currentBitrate: Int? = nil

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var sleepCountdownTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var metadataTimer: Timer?

    private var currentArtwork: MPMediaItemArtwork?
    private var lastDisplayedArtURL: String?

    private init() {
        setupAudioSession()
        setupRemoteControls()
        setupRouteObserver()
    }

    private func setupRouteObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        updateAirPlayState()
    }

    @objc private func audioRouteChanged(_ notification: Notification) {
        updateAirPlayState()
    }

    func updateAirPlayState() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        let active = outputs.contains {
            $0.portType == .airPlay ||
            $0.portType == .bluetoothA2DP ||
            $0.portType == .bluetoothLE ||
            $0.portType == .bluetoothHFP
        }
        DispatchQueue.main.async {
            self.isAirPlayActive = active
        }
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.allowAirPlay, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[AudioPlayerService] Failed to configure audio session: \(error)")
        }
    }

    func play(station: RadioStation) {
        reconnectAttempts = 0
        lastDisplayedArtURL = nil
        currentArtwork = nil
        startStream(station: station)
    }

    private func startStream(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        stopReconnectTimer()
        stopMetadataTimer()

        currentStation = station
        isBuffering = true

        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: playerItem)
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        timeControlObserver?.invalidate()

        setPlaceholderNowPlayingInfo(for: station)

        playerItem = AVPlayerItem(url: url)
        playerItem?.preferredForwardBufferDuration = 5
        player = AVPlayer(playerItem: playerItem)
        player?.allowsExternalPlayback = false
        player?.automaticallyWaitsToMinimizeStalling = true

        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                if item.status == .readyToPlay {
                    self?.player?.play()
                } else if item.status == .failed {
                    self?.scheduleReconnect()
                }
            }
        }

        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new]) { [weak self] avPlayer, _ in
            DispatchQueue.main.async {
                guard self?.isPlaying == true else { return }
                switch avPlayer.timeControlStatus {
                case .playing:
                    self?.isBuffering = false
                    self?.playerItem?.preferredForwardBufferDuration = 0
                    self?.updateBitrate()
                case .waitingToPlayAtSpecifiedRate:
                    self?.isBuffering = true
                case .paused:
                    break
                @unknown default:
                    break
                }
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemFailedToPlay),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: playerItem
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStalled),
            name: AVPlayerItem.playbackStalledNotification,
            object: playerItem
        )

        isPlaying = true

        DispatchQueue.main.async {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }

        MetadataService.shared.startPolling(apiURL: station.apiURL)
        startMetadataTimer()
    }

    private func setPlaceholderNowPlayingInfo(for station: RadioStation) {
        var info = [String: Any]()
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        info[MPMediaItemPropertyTitle] = tr("Loading...", "Wird geladen...", lang)
        info[MPMediaItemPropertyArtist] = station.displayName
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        if !station.showSongArt, let imageData = station.customImageData, let image = UIImage(data: imageData) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            currentArtwork = artwork
            info[MPMediaItemPropertyArtwork] = artwork
        }

        DispatchQueue.main.async {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func pause() {
        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: playerItem)
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        statusObserver = nil
        timeControlObserver?.invalidate()
        timeControlObserver = nil

        isPlaying = false
        isBuffering = false
        currentBitrate = nil

        DispatchQueue.main.async {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func resume() {
        guard let station = currentStation else { return }
        play(station: station)
    }

    func stop() {
        player?.pause()
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.playbackStalledNotification, object: playerItem)
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        statusObserver = nil
        timeControlObserver?.invalidate()
        timeControlObserver = nil
        isPlaying = false
        isBuffering = false
        currentBitrate = nil
        stopMetadataTimer()
        stopReconnectTimer()
        cancelSleepTimer()
        MetadataService.shared.stopPolling()
        currentStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func setSleepTimer(minutes: Int) {
        sleepCountdownTimer?.invalidate()
        sleepTimerEnd = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepCountdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let end = self.sleepTimerEnd else { return }
            DispatchQueue.main.async { [weak self] in
                if Date() >= end { self?.stop() }
            }
        }
    }

    func cancelSleepTimer() {
        sleepCountdownTimer?.invalidate()
        sleepCountdownTimer = nil
        sleepTimerEnd = nil
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    private func startMetadataTimer() {
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    private func stopMetadataTimer() {
        metadataTimer?.invalidate()
        metadataTimer = nil
    }

    private func updateBitrate() {
        if let events = playerItem?.accessLog()?.events,
           let last = events.last,
           last.indicatedBitrate > 0 {
            currentBitrate = Int(last.indicatedBitrate / 1000)
            return
        }
        guard let item = playerItem else { return }
        Task {
            guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first,
                  let rate = try? await track.load(.estimatedDataRate),
                  rate > 0 else { return }
            await MainActor.run { self.currentBitrate = Int(rate / 1000) }
        }
    }

    @objc private func playerItemFailedToPlay() {
        DispatchQueue.main.async { self.isBuffering = true }
        scheduleReconnect()
    }

    @objc private func playbackStalled() {
        DispatchQueue.main.async { self.isBuffering = true }
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < 5 else { return }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, let station = self.currentStation else { return }
            self.reconnectAttempts += 1
            self.startStream(station: station)
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.stopCommand.isEnabled = false

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, self.currentStation != nil else { return .commandFailed }
            self.resume()
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }

    func updateNowPlayingInfo() {
        var info = [String: Any]()

        let title = MetadataService.shared.currentTrack?.title ?? "Live Stream"
        let artist = MetadataService.shared.currentTrack?.artist ?? currentStation?.displayName ?? "Radio"

        info[MPMediaItemPropertyTitle] = title
        info[MPMediaItemPropertyArtist] = artist
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0

        let showSongArt = currentStation?.showSongArt ?? false

        if !showSongArt {
            if let imageData = currentStation?.customImageData,
               let image = UIImage(data: imageData) {
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                currentArtwork = artwork
                lastDisplayedArtURL = nil
                info[MPMediaItemPropertyArtwork] = artwork
            } else if let existing = currentArtwork {
                info[MPMediaItemPropertyArtwork] = existing
            }
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
            return
        }

        let artURL = MetadataService.shared.currentTrack?.art ?? MetadataService.shared.stationArtURL

        if let urlString = artURL, let url = URL(string: urlString) {
            if urlString != lastDisplayedArtURL {
                lastDisplayedArtURL = urlString
                URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                    guard let self else { return }
                    if let data = data, let image = UIImage(data: data) {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        self.currentArtwork = artwork
                        var updatedInfo = info
                        updatedInfo[MPMediaItemPropertyArtwork] = artwork
                        DispatchQueue.main.async {
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }
                }.resume()
            } else if let existing = currentArtwork {
                info[MPMediaItemPropertyArtwork] = existing
                DispatchQueue.main.async {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } else {
                DispatchQueue.main.async {
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            }
        } else {
            if let existing = currentArtwork {
                info[MPMediaItemPropertyArtwork] = existing
            }
            DispatchQueue.main.async {
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
}
