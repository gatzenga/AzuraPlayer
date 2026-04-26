import CarPlay
import UIKit
import Combine

final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var cancellables = Set<AnyCancellable>()
    private weak var stationsTemplate: CPListTemplate?
    private weak var historyTemplate: CPListTemplate?
    private var artworkCache: [UUID: UIImage] = [:]
    private var loadingArtworkIDs = Set<UUID>()

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
    }

    // MARK: - Setup

    private func setupTemplates() {
        let stations = makeStationsTemplate()
        let history = makeHistoryTemplate()
        let tabBar = CPTabBarTemplate(templates: [stations, history])
        interfaceController?.setRootTemplate(tabBar, animated: false, completion: nil)
    }

    private func observeChanges() {
        StationStore.shared.$stations
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in self?.refreshStations() }
            .store(in: &cancellables)

        PlaybackHistoryStore.shared.$entries
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .sink { [weak self] _ in self?.refreshHistory() }
            .store(in: &cancellables)
    }

    // MARK: - Stations

    private func makeStationsTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: tr("Stations", "Stationen"),
            sections: [CPListSection(items: stationItems())]
        )
        template.tabImage = UIImage(systemName: "radio")
        stationsTemplate = template
        return template
    }

    private func stationItems() -> [CPListItem] {
        StationStore.shared.stations.map { station in
            let image: UIImage?
            if let data = station.customImageData {
                image = UIImage(data: data)
            } else {
                image = UIImage(systemName: "radio")
            }
            let item = CPListItem(text: station.displayName, detailText: nil, image: image)
            item.handler = { [weak self] _, completion in
                AudioPlayerService.shared.play(station: station)
                self?.interfaceController?.pushTemplate(
                    CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            return item
        }
    }

    private func refreshStations() {
        stationsTemplate?.updateSections([CPListSection(items: stationItems())])
    }

    // MARK: - History

    private func makeHistoryTemplate() -> CPListTemplate {
        let template = CPListTemplate(
            title: tr("History", "Verlauf"),
            sections: [CPListSection(items: historyItems())]
        )
        template.tabImage = UIImage(systemName: "clock")
        historyTemplate = template
        loadMissingArtwork()
        return template
    }

    private func historyItems() -> [CPListItem] {
        PlaybackHistoryStore.shared.entries.map { entry in
            let title = entry.artist.isEmpty
                ? entry.songTitle
                : "\(entry.artist) – \(entry.songTitle)"
            let image = artworkCache[entry.id] ?? UIImage(systemName: "music.note")
            return CPListItem(text: title, detailText: entry.stationName, image: image)
        }
    }

    private func refreshHistory() {
        historyTemplate?.updateSections([CPListSection(items: historyItems())])
        loadMissingArtwork()
    }

    private func loadMissingArtwork() {
        for entry in PlaybackHistoryStore.shared.entries {
            guard artworkCache[entry.id] == nil,
                  !loadingArtworkIDs.contains(entry.id),
                  let urlString = entry.artworkURL,
                  let url = URL(string: urlString) else { continue }
            loadingArtworkIDs.insert(entry.id)
            Task {
                defer { loadingArtworkIDs.remove(entry.id) }
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = UIImage(data: data) else { return }
                artworkCache[entry.id] = image
                historyTemplate?.updateSections([CPListSection(items: historyItems())])
            }
        }
    }
}
