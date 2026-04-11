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
    private var icyStreamURL: String?
    private var generation = 0

    func startPolling(station: RadioStation) {
        if !station.apiURL.isEmpty {
            startPolling(apiURL: station.apiURL)
        } else {
            startICYPolling(streamURL: station.streamURL)
        }
    }

    private func startICYPolling(streamURL: String) {
        if icyStreamURL == streamURL && currentAPIURL == nil && timer != nil { return }

        stopPolling()
        icyStreamURL = streamURL
        currentAPIURL = nil

        currentTrack = nil
        stationName = nil
        stationArtURL = nil
        isLive = false
        isOnline = true
        isConnecting = false

        let gen = generation
        Task { await fetchICYMetadata(from: streamURL, generation: gen) }

        timer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let url = self.icyStreamURL else { return }
                let gen = self.generation
                Task { await self.fetchICYMetadata(from: url, generation: gen) }
            }
    }

    @MainActor
    private func fetchICYMetadata(from urlString: String, generation: Int) async {
        guard let url = URL(string: urlString) else { return }
        let (name, track) = await ICYMetadataFetcher.fetch(from: url)
        guard self.generation == generation else { return }
        if let name { stationName = name }
        if let track, currentTrack?.title != track.title || currentTrack?.artist != track.artist {
            currentTrack = track
        }
    }

    func startPolling(apiURL: String) {
        if currentAPIURL == apiURL && icyStreamURL == nil && timer != nil { return }

        stopPolling()
        currentAPIURL = apiURL
        icyStreamURL = nil

        currentTrack = nil
        stationName = nil
        stationArtURL = nil
        isLive = false
        isOnline = false

        guard !apiURL.isEmpty else {
            isConnecting = false
            return
        }

        isConnecting = true

        let gen = generation
        Task { await fetchNowPlaying(generation: gen) }

        timer = Timer.publish(every: 3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let gen = self.generation
                Task { await self.fetchNowPlaying(generation: gen) }
            }
    }

    func stopPolling() {
        timer?.cancel()
        timer = nil
        generation += 1
    }

    @MainActor
    private func fetchNowPlaying(generation: Int) async {
        guard let urlString = currentAPIURL,
              let url = URL(string: urlString) else { return }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try MetadataService.decoder.decode(NowPlayingResponse.self, from: data)

            guard self.generation == generation else { return }

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
            guard self.generation == generation else { return }
            isConnecting = false
        }
    }
}

// Reads ICY headers and in-stream metadata from a radio stream URL.
private class ICYMetadataFetcher: NSObject, URLSessionDataDelegate {
    private var receivedData = Data()
    private var metaint: Int?
    private var icyName: String?
    private var continuation: CheckedContinuation<(String?, SongInfo?), Never>?
    private var completed = false
    private var task: URLSessionDataTask?

    static func fetch(from url: URL) async -> (String?, SongInfo?) {
        return await withCheckedContinuation { continuation in
            let fetcher = ICYMetadataFetcher()
            fetcher.continuation = continuation

            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.timeoutIntervalForResource = 8
            let session = URLSession(configuration: config, delegate: fetcher, delegateQueue: nil)

            var request = URLRequest(url: url)
            request.setValue("1", forHTTPHeaderField: "Icy-MetaData")

            let task = session.dataTask(with: request)
            fetcher.task = task
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        if let http = response as? HTTPURLResponse {
            icyName = http.allHeaderFields["icy-name"] as? String
            if let metaintStr = http.allHeaderFields["icy-metaint"] as? String {
                metaint = Int(metaintStr)
            }
        }
        // If no in-stream metadata interval, station name from headers is all we can get
        if metaint == nil {
            finish()
            completionHandler(.cancel)
        } else {
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        if let metaint, receivedData.count >= metaint + 1 {
            finish()
            task?.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        finish()
    }

    private func finish() {
        guard !completed else { return }
        completed = true
        continuation?.resume(returning: (icyName, parsedTrack()))
    }

    private func parsedTrack() -> SongInfo? {
        guard let metaint, receivedData.count > metaint else { return nil }
        let lengthByte = receivedData[metaint]
        let metaLen = Int(lengthByte) * 16
        guard metaLen > 0, receivedData.count >= metaint + 1 + metaLen else { return nil }
        let metaData = receivedData[(metaint + 1)..<(metaint + 1 + metaLen)]
        guard let str = String(bytes: metaData, encoding: .utf8) ?? String(bytes: metaData, encoding: .isoLatin1) else { return nil }
        guard let start = str.range(of: "StreamTitle='"),
              let end = str[start.upperBound...].range(of: "'") else { return nil }
        let streamTitle = String(str[start.upperBound..<end.lowerBound])
        guard !streamTitle.isEmpty else { return nil }
        let parts = streamTitle.components(separatedBy: " - ")
        if parts.count >= 2 {
            return SongInfo(title: parts[1...].joined(separator: " - "), artist: parts[0], art: nil, album: nil)
        }
        return SongInfo(title: streamTitle, artist: "", art: nil, album: nil)
    }
}
