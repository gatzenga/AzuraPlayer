import Foundation
import WatchConnectivity
import Combine

class WatchStationStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var stations: [RadioStation] = []
    @Published var isReachable: Bool = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
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
            self.stations = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["stations"] as? Data,
              let decoded = try? JSONDecoder().decode([RadioStation].self, from: data) else { return }
        DispatchQueue.main.async {
            self.stations = decoded.sorted { $0.sortOrder < $1.sortOrder }
        }
    }
}
