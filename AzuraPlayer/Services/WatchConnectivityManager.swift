import Foundation
import Combine
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func sendNowPlaying(stationName: String, songTitle: String, artist: String, isPlaying: Bool) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        let message: [String: Any] = [
            "stationName": stationName,
            "songTitle": songTitle,
            "artist": artist,
            "isPlaying": isPlaying
        ]
        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}
