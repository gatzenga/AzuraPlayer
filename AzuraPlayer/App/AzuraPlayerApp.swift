import SwiftUI

/// Systemsprache: Deutsch wenn das Gerät auf Deutsch eingestellt ist, sonst Englisch.
let appLang: String = Locale.preferredLanguages.first?.hasPrefix("de") == true ? "de" : "en"

/// Localized string: returns English by default, German if appLang == "de".
func tr(_ en: String, _ de: String, _ lang: String = appLang) -> String {
    lang == "de" ? de : en
}

@main
struct AzuraPlayerApp: App {
    @StateObject private var store = StationStore()
    @StateObject private var player = AudioPlayerService.shared
    @AppStorage("themeColor") private var themeColorName = "blue"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(player)
                .tint(AppTheme.color(for: themeColorName))
        }
    }
}
