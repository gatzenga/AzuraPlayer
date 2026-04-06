import Foundation
import WatchConnectivity
import Combine

class WatchStationStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var stations: [RadioStation] = []
    @Published var isReachable: Bool = false

    private let saveKey = "watch_cached_stations"

    override init() {
        super.init()
        loadLocal() // Sofort aus lokalem Cache laden → keine leere Liste beim Start
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Lokaler Cache

    private func saveLocal(_ decoded: [RadioStation]) {
        if let data = try? JSONEncoder().encode(decoded) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) else { return }
        stations = decoded.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            // Bereits gespeicherten Context vom iPhone lesen (funktioniert ohne offene iPhone App)
            if let data = session.receivedApplicationContext["stations"] as? Data,
               let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) {
                let sorted = decoded.sorted { $0.sortOrder < $1.sortOrder }
                self.stations = sorted
                self.saveLocal(sorted)
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessageData messageData: Data) {
        guard let decoded = try? JSONDecoder().decode([RadioStation].self, from: messageData) else { return }
        DispatchQueue.main.async {
            let sorted = decoded.sorted { $0.sortOrder < $1.sortOrder }
            self.stations = sorted
            self.saveLocal(sorted)
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["stations"] as? Data,
              let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) else { return }
        DispatchQueue.main.async {
            let sorted = decoded.sorted { $0.sortOrder < $1.sortOrder }
            self.stations = sorted
            self.saveLocal(sorted)
        }
    }
}
