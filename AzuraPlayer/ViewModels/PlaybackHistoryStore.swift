import Foundation
import Combine

class PlaybackHistoryStore: ObservableObject {
    static let shared = PlaybackHistoryStore()

    @Published var entries: [PlaybackEntry] = []

    private let maxEntries = 100
    private let saveKey = "playback_history"

    init() {
        load()
    }

    func addEntry(song: SongInfo, stationName: String, artworkURL: String?) {
        guard !song.title.isEmpty else { return }

        // Duplikat verhindern: nur speichern wenn sich Titel oder Künstler geändert hat
        if let last = entries.first {
            if last.songTitle == song.title && last.artist == song.artist { return }
        }

        let entry = PlaybackEntry(
            songTitle: song.title,
            artist: song.artist,
            stationName: stationName,
            artworkURL: artworkURL
        )

        entries.insert(entry, at: 0)
        if entries.count > maxEntries { entries.removeLast() }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([PlaybackEntry].self, from: data) {
            entries = decoded
        }
    }
}
