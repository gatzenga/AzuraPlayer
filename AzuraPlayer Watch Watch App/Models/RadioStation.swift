import Foundation

struct RadioStation: Identifiable, Codable {
    var id: UUID = UUID()
    var customName: String?
    var streamURL: String
    var apiURL: String
    var customImageData: Data?
    var showSongArt: Bool = false
    var sortOrder: Int = 0

    var fetchedStationName: String?
    var fetchedStationArtURL: String?

    var displayName: String {
        if let custom = customName, !custom.isEmpty { return custom }
        if let fetched = fetchedStationName, !fetched.isEmpty { return fetched }
        return streamURL
    }

    enum CodingKeys: String, CodingKey {
        case id, customName, streamURL, apiURL
        case customImageData, showSongArt, sortOrder
        case fetchedStationName, fetchedStationArtURL
    }
}

