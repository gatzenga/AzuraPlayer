import Foundation
import Combine

class MetadataService: ObservableObject {
    static let shared = MetadataService()
    private static let decoder = JSONDecoder()

    @Published var currentTrack: SongInfo?
    @Published var stationName: String?
    @Published var stationArtURL: String?
    @Published var isLive: Bool = false
    @Published var isOnline: Bool = false
    @Published var isConnecting: Bool = false

    private var timer: AnyCancellable?
    private var currentAPIURL: String?

    func startPolling(apiURL: String) {
        if currentAPIURL == apiURL && timer != nil { return }

        stopPolling()
        currentAPIURL = apiURL

        currentTrack = nil
        stationName = nil
        stationArtURL = nil
        isLive = false
        isOnline = false
        isConnecting = true

        Task { await fetchNowPlaying() }

        timer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.fetchNowPlaying() }
            }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
    }

    @MainActor
    private func fetchNowPlaying() async {
        guard let urlString = currentAPIURL,
              let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try MetadataService.decoder.decode(NowPlayingResponse.self, from: data)

            stationName = response.station.name
            isOnline = response.isOnline ?? true
            isLive = response.live?.isLive ?? false
            isConnecting = false

            if let shortcode = response.station.shortcode,
               let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
               let scheme = components.scheme,
               let host = components.host {
                let newArtURL = "\(scheme)://\(host)/api/station/\(shortcode)/art"
                if stationArtURL != newArtURL {
                    stationArtURL = newArtURL
                }
            }

            if let newSong = response.nowPlaying?.song {
                if currentTrack?.title != newSong.title || currentTrack?.artist != newSong.artist {
                    currentTrack = newSong
                    let artURL = newSong.art ?? stationArtURL
                    PlaybackHistoryStore.shared.addEntry(
                        song: newSong,
                        stationName: response.station.name,
                        artworkURL: artURL
                    )
                }
            }

        } catch {
            isConnecting = false
        }
    }
}
