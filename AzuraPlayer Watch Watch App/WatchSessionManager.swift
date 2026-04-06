import Foundation
import Combine
import WatchConnectivity

class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()

    @Published var stationName: String = ""
    @Published var songTitle: String = ""
    @Published var artist: String = ""
    @Published var isPlaying: Bool = false
    @Published var isConnected: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendCommand(_ command: String) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["command": command], replyHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.stationName = message["stationName"] as? String ?? ""
            self.songTitle = message["songTitle"] as? String ?? ""
            self.artist = message["artist"] as? String ?? ""
            self.isPlaying = message["isPlaying"] as? Bool ?? false
        }
    }
}
