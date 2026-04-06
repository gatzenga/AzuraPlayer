import Foundation
import SwiftUI
import Combine
import WatchConnectivity

class StationStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var stations: [RadioStation] = []

    private let saveKey = "saved_stations"

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        load()
        stations.forEach { fetchStationName(for: $0) }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        sendToWatch()
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // MARK: - Watch Sync

    func sendToWatch() {
        guard WCSession.default.activationState == .activated else { return }
        // customImageData weglassen – updateApplicationContext hat ein 65 KB-Limit
        let lite = stations.map { s -> RadioStation in
            var copy = s
            copy.customImageData = nil
            return copy
        }
        guard let data = try? JSONEncoder().encode(lite) else { return }
        try? WCSession.default.updateApplicationContext(["stations": data])
    }

    // MARK: - CRUD

    func add(station: RadioStation) {
        var s = station
        s.sortOrder = stations.count
        stations.append(s)
        save()
        fetchStationName(for: s)
        sendToWatch()
    }

    func update(station: RadioStation) {
        if let idx = stations.firstIndex(where: { $0.id == station.id }) {
            stations[idx] = station
            save()
            fetchStationName(for: station)
            sendToWatch()
        }
    }

    func delete(station: RadioStation) {
        stations.removeAll { $0.id == station.id }
        save()
        sendToWatch()
    }

    func move(from: IndexSet, to: Int) {
        stations.move(fromOffsets: from, toOffset: to)
        save()
        sendToWatch()
    }

    // MARK: - Fetch / Save / Load

    func fetchStationName(for station: RadioStation) {
        guard !station.apiURL.isEmpty,
              let url = URL(string: station.apiURL) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(NowPlayingResponse.self, from: data)
                await MainActor.run {
                    if let idx = self.stations.firstIndex(where: { $0.id == station.id }) {
                        self.stations[idx].fetchedStationName = response.station.name
                        self.save()        // Name in UserDefaults persistieren
                        self.sendToWatch() // Watch mit aktuellem Namen versorgen
                    }
                }
            } catch {
                print("fetchStationName error: \(error)")
            }
        }
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

