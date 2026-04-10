import Foundation
import SwiftUI
import Combine

class StationStore: ObservableObject {
    @Published var stations: [RadioStation] = []

    private let saveKey = "saved_stations"
    private static let decoder = JSONDecoder()

    init() {
        load()
        stations.forEach { fetchStationName(for: $0) }
    }

    func add(station: RadioStation) {
        var s = station
        s.sortOrder = stations.count
        stations.append(s)
        save()
        fetchStationName(for: s)
    }

    func update(station: RadioStation) {
        if let idx = stations.firstIndex(where: { $0.id == station.id }) {
            let old = stations[idx]
            var updated = station

            if old.apiURL != station.apiURL || old.streamURL != station.streamURL {
                updated.fetchedStationName = nil
            }

            stations[idx] = updated
            save()
            fetchStationName(for: updated)

            let player = AudioPlayerService.shared
            guard player.currentStation?.id == updated.id else { return }

            if old.streamURL != updated.streamURL {
                player.play(station: updated)
            } else if old.apiURL != updated.apiURL {
                player.currentStation = updated
                MetadataService.shared.stopPolling()
                MetadataService.shared.startPolling(apiURL: updated.apiURL)
            } else {
                player.currentStation = updated
            }
        }
    }

    func delete(station: RadioStation) {
        stations.removeAll { $0.id == station.id }
        for i in stations.indices { stations[i].sortOrder = i }
        save()
    }

    func move(from: IndexSet, to: Int) {
        stations.move(fromOffsets: from, toOffset: to)
        for i in stations.indices { stations[i].sortOrder = i }
        save()
    }

    func fetchStationName(for station: RadioStation) {
        guard !station.apiURL.isEmpty,
              let url = URL(string: station.apiURL) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try StationStore.decoder.decode(NowPlayingResponse.self, from: data)
                await MainActor.run {
                    if let idx = self.stations.firstIndex(where: { $0.id == station.id }) {
                        self.stations[idx].fetchedStationName = response.station.name
                        self.save()
                    }
                }
            } catch {
                print("[StationStore] fetchStationName failed for \(station.apiURL): \(error)")
            }
        }
    }

    func importStations(_ newStations: [RadioStation]) {
        stations.append(contentsOf: newStations)
        for i in stations.indices { stations[i].sortOrder = i }
        save()
        newStations.forEach { fetchStationName(for: $0) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stations) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
            stations = decoded
        }
    }
}
