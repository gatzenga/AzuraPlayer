import Foundation
import AVFoundation
import MediaPlayer
import Combine

class WatchNowPlayingManager: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentStation: RadioStation?
    @Published var songTitle: String = ""
    @Published var artistName: String = ""
    @Published var artworkURL: String?

    private var player: AVPlayer?
    private var pollTask: Task<Void, Never>?

    func play(station: RadioStation) {
        guard let url = URL(string: station.streamURL) else { return }

        player?.pause()
        player = AVPlayer(url: url)
        player?.play()
        currentStation = station
        isPlaying = true

        startPolling(station: station)
        updateNowPlaying()
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        pollTask?.cancel()
        pollTask = nil
    }

    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

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
            self.songTitle = response.nowPlaying.song.title
            self.artistName = response.nowPlaying.song.artist
            self.artworkURL = response.nowPlaying.song.art
            self.updateNowPlaying()
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = songTitle.isEmpty ? (currentStation?.displayName ?? "") : songTitle
        info[MPMediaItemPropertyArtist] = artistName
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
