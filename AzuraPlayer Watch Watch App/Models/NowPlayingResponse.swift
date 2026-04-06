import Foundation

struct NowPlayingResponse: Codable {
    let station: StationInfo
    let nowPlaying: NowPlayingTrack

    enum CodingKeys: String, CodingKey {
        case station
        case nowPlaying = "now_playing"
    }
}

struct StationInfo: Codable {
    let name: String
}

struct NowPlayingTrack: Codable {
    let song: SongInfo
}

struct SongInfo: Codable {
    let title: String
    let artist: String
    let art: String?
}
