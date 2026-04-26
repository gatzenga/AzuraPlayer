# CarPlay-Integration – Design-Spec

**Datum:** 2026-04-25  
**Projekt:** AzuraPlayer  
**Ziel:** Saubere CarPlay-Unterstützung für Audio-Streaming mit Stationsliste, Verlauf und Now Playing.

---

## Voraussetzungen (bereits erfüllt)

- Entitlement `com.apple.developer.carplay-audio` → vorhanden in `AzuraPlayer.entitlements`
- UIBackgroundModes `audio` → vorhanden in `Info.plist`

---

## Architektur

### Neue / geänderte Dateien

| Datei | Änderung |
|-------|----------|
| `AzuraPlayer/Info.plist` | CarPlay-Scene-Konfiguration hinzufügen |
| `AzuraPlayer/ViewModels/StationStore.swift` | `static let shared = StationStore()` hinzufügen; `AzuraPlayerApp` nutzt `StationStore.shared` |
| `AzuraPlayer/App/AzuraPlayerApp.swift` | `@StateObject private var store = StationStore()` → `StationStore.shared` |
| `AzuraPlayer/CarPlay/CarPlaySceneDelegate.swift` | Neue Datei (siehe unten) |
| `AzuraPlayer.xcodeproj/project.pbxproj` | Neue Datei referenzieren |

---

## Info.plist – Scene-Konfiguration

```xml
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>CPTemplateApplicationSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>CarPlay Configuration</string>
                <key>UISceneClassName</key>
                <string>CPTemplateApplicationScene</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).CarPlaySceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

---

## StationStore – Singleton

```swift
static let shared = StationStore()
```

`AzuraPlayerApp` nutzt danach `StationStore.shared` anstatt `@StateObject private var store = StationStore()`.

---

## CarPlaySceneDelegate

```swift
import CarPlay
import UIKit
import Combine

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()
    private weak var stationsTemplate: CPListTemplate?
    private weak var historyTemplate: CPListTemplate?

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                   didConnect controller: CPInterfaceController) {
        interfaceController = controller
        setupTemplates()
        observeChanges()
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                   didDisconnect controller: CPInterfaceController) {
        interfaceController = nil
        cancellables.removeAll()
    }
}
```

### Tabs

**Tab 1 – Stationen (`CPListTemplate`)**
- Titel: `tr("Stations", "Stationen")`
- Tab-Icon: `UIImage(systemName: "radio")`
- Pro Station ein `CPListItem(text: station.displayName, detailText: nil, image: stationImage(station))`
- `stationImage`: lädt `customImageData` als `UIImage`, sonst Placeholder (`UIImage(systemName: "radio")`)
- Handler: `AudioPlayerService.shared.play(station:)` → `interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true)`

**Tab 2 – Verlauf (`CPListTemplate`)**
- Titel: `tr("History", "Verlauf")`
- Tab-Icon: `UIImage(systemName: "clock")`
- Pro Eintrag: `CPListItem(text: titel, detailText: stationName, image: artworkImage(entry))`
- `artworkImage`: synchron via Placeholder, async-Nachlade via `URLSession` + `template.updateSections`
- Kein Handler (read-only)

**Now Playing (`CPNowPlayingTemplate.shared`)**
- Wird von CarPlay automatisch verwaltet
- Liest Titel, Künstler und Artwork aus `MPNowPlayingInfoCenter` — wird bereits von `AudioPlayerService` befüllt
- Play/Pause-Button in CarPlay triggert `MPRemoteCommandCenter` — wird bereits von `AudioPlayerService` registriert

### Live-Updates via Combine

```swift
StationStore.shared.$stations
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in self?.refreshStations() }
    .store(in: &cancellables)

PlaybackHistoryStore.shared.$entries
    .receive(on: DispatchQueue.main)
    .sink { [weak self] _ in self?.refreshHistory() }
    .store(in: &cancellables)
```

`refreshStations()` und `refreshHistory()` rufen `template.updateSections([...])` auf.

### Artwork-Nachladestrategie (History)

1. Zunächst Placeholder anzeigen
2. Alle URLs per `URLSession.shared.dataTask` asynchron laden
3. Nach jedem Download `refreshHistory()` aufrufen (gecachte Images in Dictionary)

---

## Nicht verändert

- `AudioPlayerService`, `MetadataService`, `PlaybackHistoryStore` – keine Änderungen
- iOS-App-UI (`ContentView`, `StationListView`, etc.) – keine Änderungen
- Accent-Farbe entfällt in CarPlay automatisch (kein Custom-Tinting in CarPlay-Templates)
- Settings bleiben in der iOS-App unverändert

---

## Scope

Ausdrücklich **nicht** in diesem Scope:
- CarPlay-spezifische Einstellungen
- Suche in der Stationsliste
- Favoriten oder Filter
