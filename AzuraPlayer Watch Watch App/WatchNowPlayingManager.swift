import Foundation
import AVFoundation
import MediaPlayer
import WatchKit
import Combine

class WatchNowPlayingManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    @Published var isPlaying: Bool = false
    @Published var currentStation: RadioStation?
    @Published var songTitle: String = ""
    @Published var artistName: String = ""
    @Published var artworkURL: String?

    private var player: AVPlayer?
    private var pollTask: Task<Void, Never>?
    private var extendedSession: WKExtendedRuntimeSession?

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteControls()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Watch audio session error: \(error)")
        }
    }

    private func setupRemoteControls() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, let station = self.currentStation else { return .commandFailed }
            self.play(station: station)
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }
    }

    func play(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        player?.pause()
        player = nil

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.play()

        currentStation = station
        isPlaying = true

        startExtendedSession()
        startPolling(station: station)
        updateNowPlaying()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentStation = nil
        songTitle = ""
        artistName = ""
        artworkURL = nil
        pollTask?.cancel()
        pollTask = nil
        extendedSession?.invalidate()
        extendedSession = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func pause() {
        player?.pause()
        player = nil
        isPlaying = false
        // pollTask keeps running so metadata updates continue
        updateNowPlaying()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else if let station = currentStation {
            play(station: station)
        }
    }

    // MARK: - Extended Runtime Session (background audio)

    private func startExtendedSession() {
        extendedSession?.invalidate()
        let session = WKExtendedRuntimeSession()
        session.delegate = self
        session.start()
        extendedSession = session
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Watch extended session started")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Session is about to expire – restart if still playing
        if isPlaying, let station = currentStation {
            startExtendedSession()
            _ = station // keep reference
        }
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession,
                                 didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
                                 error: Error?) {
        print("Watch extended session invalidated: \(reason.rawValue)")
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

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = songTitle.isEmpty ? (currentStation?.displayName ?? "") : songTitle
        info[MPMediaItemPropertyArtist] = artistName
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
