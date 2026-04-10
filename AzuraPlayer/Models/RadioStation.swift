import Foundation

struct RadioStation: Identifiable, Codable {
    let id: UUID
    var customName: String?
    var streamURL: String
    var apiURL: String
    var customImageData: Data?
    var showSongArt: Bool = false
    var autoFillAPI: Bool = false
    var sortOrder: Int = 0

    var fetchedStationName: String?
    var fetchedStationArtURL: String?

    var displayName: String {
        if let custom = customName, !custom.isEmpty { return custom }
        if let fetched = fetchedStationName, !fetched.isEmpty { return fetched }
        return streamURL
    }
}

extension RadioStation {
    init(streamURL: String, apiURL: String) {
        self.id = UUID()
        self.customName = nil
        self.streamURL = streamURL
        self.apiURL = apiURL
        self.customImageData = nil
        self.showSongArt = false
        self.autoFillAPI = false
        self.sortOrder = 0
        self.fetchedStationName = nil
        self.fetchedStationArtURL = nil
    }
}
