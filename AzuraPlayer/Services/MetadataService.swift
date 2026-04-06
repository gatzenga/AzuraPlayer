import Foundation
import Combine

class MetadataService: ObservableObject {
    static let shared = MetadataService()

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
        isConnecting = true

        Task { await fetchNowPlaying() }

        timer = Timer.publish(every: 5, on: .main, in: .common)
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
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(NowPlayingResponse.self, from: data)

            stationName = response.station.name
            isOnline = response.isOnline
            isLive = response.live?.isLive ?? false
            isConnecting = false

            let shortcode = response.station.shortcode
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
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
                }
            }

        } catch {
            isConnecting = false
        }
    }
}
