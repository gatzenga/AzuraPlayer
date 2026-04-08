import SwiftUI
import PhotosUI

struct AddEditStationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: StationStore
    @AppStorage("appLanguage") private var lang = "en"

    var editStation: RadioStation?

    @State private var customName: String = ""
    @State private var streamURL: String = ""
    @State private var apiURL: String = ""
    @State private var showSongArt: Bool = false
    @State private var autoFillAPI: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var customImageData: Data?

    var isEditing: Bool { editStation != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("Stream Data", "Stream-Daten", lang)) {
                    TextField(tr("Name (optional – uses station name)", "Name (optional – sonst Sendername)", lang), text: $customName)
                        .autocorrectionDisabled()

                    TextField("Stream-URL", text: $streamURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: streamURL) { _, newValue in
                            if autoFillAPI, let derived = derivedAPIURL(from: newValue) {
                                apiURL = derived
                            }
                        }

                    TextField("API-URL (Now Playing)", text: $apiURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .disabled(autoFillAPI)
                        .foregroundStyle(autoFillAPI ? .secondary : .primary)

                    Toggle(tr("Fill API URL from stream URL", "API-URL aus Stream-URL ableiten", lang), isOn: $autoFillAPI)
                        .onChange(of: autoFillAPI) { _, enabled in
                            if enabled, let derived = derivedAPIURL(from: streamURL) {
                                apiURL = derived
                            }
                        }
                }

                Section(tr("Cover", "Cover", lang)) {
                    Toggle(tr("Show song cover (instead of station image)", "Song-Cover anzeigen (statt Senderbild)", lang), isOn: $showSongArt)

                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack {
                            if let data = customImageData,
                               let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title2)
                            }
                            Text(customImageData == nil
                                 ? tr("Choose custom cover", "Custom Cover wählen", lang)
                                 : tr("Change cover", "Cover ändern", lang))
                        }
                    }

                    if customImageData != nil {
                        Button(tr("Remove cover", "Cover entfernen", lang), role: .destructive) {
                            customImageData = nil
                            selectedPhoto = nil
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("💡 AzuraCast API-Format:")
                            .font(.caption).bold()
                        Text("https://your-domain.com/api/nowplaying/station_shortcode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing
                             ? tr("Edit Station", "Sender bearbeiten", lang)
                             : tr("Add Station", "Sender hinzufügen", lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(streamURL.isEmpty || apiURL.isEmpty)
                }
            }
            .onChange(of: selectedPhoto) { _, new in
                Task {
                    if let data = try? await new?.loadTransferable(type: Data.self) {
                        customImageData = data
                    }
                }
            }
            .onAppear { prefill() }
        }
    }

    // Derives the AzuraCast API URL from a stream URL.
    // Example: https://radio.example.com/listen/music → https://radio.example.com/api/nowplaying/music
    private func derivedAPIURL(from streamURL: String) -> String? {
        guard let url = URL(string: streamURL),
              let scheme = url.scheme,
              let host = url.host else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let listenIdx = components.firstIndex(of: "listen"),
              listenIdx + 1 < components.count else { return nil }
        let stationName = components[listenIdx + 1]
        return "\(scheme)://\(host)/api/nowplaying/\(stationName)"
    }

    private func prefill() {
        guard let s = editStation else { return }
        customName = s.customName ?? ""
        streamURL = s.streamURL
        apiURL = s.apiURL
        showSongArt = s.showSongArt
        autoFillAPI = s.autoFillAPI
        customImageData = s.customImageData
    }

    private func save() {
        var station = editStation ?? RadioStation(streamURL: streamURL, apiURL: apiURL)
        station.customName = customName.isEmpty ? nil : customName
        station.streamURL = streamURL
        station.apiURL = apiURL
        station.showSongArt = showSongArt
        station.autoFillAPI = autoFillAPI
        station.customImageData = customImageData

        if isEditing {
            store.update(station: station)
        } else {
            store.add(station: station)
        }
        dismiss()
    }
}
