import CarPlay
import UIKit
import Combine

@MainActor
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()

    private weak var stationsTemplate: CPListTemplate?

    // Stable item caches: Items werden einmal erstellt und dann in-place mutiert
    // (setText/setImage), statt bei jedem Refresh komplette neue Items zu bauen.
    // Verhindert IPC-Storms zur CarPlay-XPC-Bridge.
    private var stationItemsByID: [UUID: CPListItem] = [:]
    private var stationOrder: [UUID] = []

    // Pre-decoded UIImage Cache für RadioStation.customImageData — sonst wird
    // bei jedem Refresh auf Main Thread neu decodiert.
    private var stationImageCache: [UUID: UIImage] = [:]
    private var stationImageDataHash: [UUID: Int] = [:]

    private static let radioPlaceholder = UIImage(systemName: "radio")

    // MARK: - CPTemplateApplicationSceneDelegate

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        setupTemplates()
        observeChanges()
    }

    func templateApplicationScene(
        _ scene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        self.interfaceController = nil
        cancellables.removeAll()
        stationItemsByID.removeAll()
        stationOrder.removeAll()
        stationImageCache.removeAll()
        stationImageDataHash.removeAll()
    }

    // MARK: - Setup

    private func setupTemplates() {
        let stations = makeStationsTemplate()
        interfaceController?.setRootTemplate(stations, animated: false, completion: nil)
    }

    private func observeChanges() {
        // Coalescing: StationStore feuert beim App-Start mehrere Updates schnell hintereinander
        // (init lädt aus UserDefaults, dann fetchStationName für jede Station async). Ohne
        // debounce würde jedes davon ein updateSections triggern.
        StationStore.shared.$stations
            .dropFirst()
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshStations() }
            .store(in: &cancellables)
    }

    // MARK: - Stations

    private func makeStationsTemplate() -> CPListTemplate {
        let items = buildStationItems()
        let template = CPListTemplate(
            title: tr("Stations", "Stationen"),
            sections: [CPListSection(items: items)]
        )
        stationsTemplate = template
        return template
    }

    /// Baut Items für die aktuelle StationStore-Liste — verwendet gecachte Items wenn
    /// vorhanden und mutiert sie in-place. Aktualisiert intern stationOrder.
    private func buildStationItems() -> [CPListItem] {
        let stations = StationStore.shared.stations
        var newOrder: [UUID] = []
        newOrder.reserveCapacity(stations.count)
        var items: [CPListItem] = []
        items.reserveCapacity(stations.count)

        var aliveIDs = Set<UUID>()
        for station in stations {
            aliveIDs.insert(station.id)
            newOrder.append(station.id)

            let image = stationImage(for: station)
            if let existing = stationItemsByID[station.id] {
                existing.setText(station.displayName)
                existing.setImage(image)
                existing.handler = makeStationHandler(for: station)
                items.append(existing)
            } else {
                let item = CPListItem(text: station.displayName, detailText: nil, image: image)
                item.handler = makeStationHandler(for: station)
                stationItemsByID[station.id] = item
                items.append(item)
            }
        }

        // Entfernte Stationen aus Caches räumen
        for id in stationItemsByID.keys where !aliveIDs.contains(id) {
            stationItemsByID.removeValue(forKey: id)
            stationImageCache.removeValue(forKey: id)
            stationImageDataHash.removeValue(forKey: id)
        }

        stationOrder = newOrder
        return items
    }

    private func makeStationHandler(for station: RadioStation) -> (CPSelectableListItem, @escaping () -> Void) -> Void {
        return { [weak self] _, completion in
            AudioPlayerService.shared.play(station: station)
            self?.interfaceController?.pushTemplate(
                CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
    }

    /// Gibt ein UIImage für die Station zurück; decodiert customImageData nur einmal pro
    /// data-Identität (Hash) und cached das Resultat.
    private func stationImage(for station: RadioStation) -> UIImage? {
        guard let data = station.customImageData else {
            stationImageCache.removeValue(forKey: station.id)
            stationImageDataHash.removeValue(forKey: station.id)
            return Self.radioPlaceholder
        }
        let hash = data.hashValue
        if stationImageDataHash[station.id] == hash, let cached = stationImageCache[station.id] {
            return cached
        }
        let image = UIImage(data: data) ?? Self.radioPlaceholder
        stationImageCache[station.id] = image
        stationImageDataHash[station.id] = hash
        return image
    }

    private func refreshStations() {
        let oldOrder = stationOrder
        let items = buildStationItems()
        // Nur wenn sich die ID-Reihenfolge tatsächlich ändert, müssen wir Sections neu setzen.
        // Bei reinen Daten-Updates (z.B. fetchedStationName kommt rein) wurden die existierenden
        // Items bereits in-place via setText/setImage mutiert.
        if oldOrder != stationOrder {
            stationsTemplate?.updateSections([CPListSection(items: items)])
        }
    }
}
