import Foundation

struct PlaybackEntry: Codable, Identifiable {
    let id: UUID
    let songTitle: String
    let artist: String
    let stationName: String
    let artworkURL: String?
    let timestamp: Date

    init(songTitle: String, artist: String, stationName: String, artworkURL: String?, timestamp: Date = Date()) {
        self.id = UUID()
        self.songTitle = songTitle
        self.artist = artist
        self.stationName = stationName
        self.artworkURL = artworkURL
        self.timestamp = timestamp
    }
}
