import AVFoundation
import MediaPlayer
import Combine
import UIKit
import SwiftUI

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()

    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentStation: RadioStation?

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var statusObserver: NSKeyValueObservation?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private var metadataTimer: Timer?

    private var currentArtwork: MPMediaItemArtwork?
    private var lastDisplayedArtURL: String?

    private init() {
        setupAudioSession()
        setupRemoteControls()
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
            print("Audio session error: \(error)")
        }
    }

    func play(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        stopReconnectTimer()
        stopMetadataTimer()

        currentArtwork = nil
        lastDisplayedArtURL = nil

        currentStation = station
        isBuffering = true
        reconnectAttempts = 0

        player?.pause()
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)

        setPlaceholderNowPlayingInfo(for: station)

        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        statusObserver = playerItem?.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .readyToPlay:
                    self?.isBuffering = false
                case .failed:
                    self?.isBuffering = false
                    self?.scheduleReconnect()
                default:
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

        player?.play()
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
        info[MPMediaItemPropertyTitle] = "Wird geladen..."
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

    // MARK: - Pause / Resume

    func pause() {
        // Player zerstören → kein Buffering im Hintergrund
        player?.pause()
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        statusObserver = nil
        NotificationCenter.default.removeObserver(self)

        isPlaying = false
        isBuffering = false
        stopMetadataTimer()
        MetadataService.shared.stopPolling()

        // playbackRate = 0 → iOS zeigt Play-Symbol (kein Quadrat)
        DispatchQueue.main.async {
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    func resume() {
        // Immer neu verbinden → Stream ist live
        guard let station = currentStation else { return }
        play(station: station)
    }

    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        statusObserver?.invalidate()
        statusObserver = nil
        isPlaying = false
        isBuffering = false
        stopMetadataTimer()
        stopReconnectTimer()
        MetadataService.shared.stopPolling()
        currentStation = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    // MARK: - Metadata Timer

    private func startMetadataTimer() {
        metadataTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNowPlayingInfo()
        }
    }

    private func stopMetadataTimer() {
        metadataTimer?.invalidate()
        metadataTimer = nil
    }

    // MARK: - Reconnect

    @objc private func playerItemFailedToPlay() {
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < 5 else { return }
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, let station = self.currentStation else { return }
            self.reconnectAttempts += 1
            self.play(station: station)
        }
    }

    private func stopReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }

    // MARK: - Remote Controls

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

    // MARK: - Now Playing Info

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
