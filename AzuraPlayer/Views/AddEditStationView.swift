import SwiftUI
import PhotosUI

struct AddEditStationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @ObservedObject var store: StationStore
    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var editStation: RadioStation?

    @State private var customName: String = ""
    @State private var streamURL: String = ""
    @State private var apiURL: String = ""
    @State private var showSongArt: Bool = false
    @State private var autoFillAPI: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var customImageData: Data?

    private var urlPathBinding: Binding<String> {
        Binding(
            get: {
                if streamURL.hasPrefix("https://") { return String(streamURL.dropFirst(8)) }
                if streamURL.hasPrefix("http://") { return String(streamURL.dropFirst(7)) }
                return streamURL
            },
            set: { streamURL = "https://\($0)" }
        )
    }

    var isEditing: Bool { editStation != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(tr("Stream Data", "Stream-Daten")) {
                    TextField(tr("Name (optional – uses station name)", "Name (optional – sonst Sendername)"), text: $customName)
                        .autocorrectionDisabled()

                    HStack(spacing: 8) {
                        Text("https://")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField(tr("(HLS recommended)", "(HLS empfohlen)"), text: urlPathBinding)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
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

                    Toggle(tr("Fill API URL from stream URL", "API-URL aus Stream-URL ableiten"), isOn: $autoFillAPI)
                        .onChange(of: autoFillAPI) { _, enabled in
                            if enabled, let derived = derivedAPIURL(from: streamURL) {
                                apiURL = derived
                            }
                        }
                }

                Section(tr("Cover", "Cover")) {
                    Toggle(tr("Show song cover (instead of station image)", "Song-Cover anzeigen (statt Senderbild)"), isOn: $showSongArt)

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
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            } else {
                                Image(systemName: "photo.badge.plus")
                                    .font(.body)
                            }
                            Text(customImageData == nil
                                 ? tr("Choose custom cover", "Custom Cover wählen")
                                 : tr("Change cover", "Cover ändern"))
                                .font(.callout)
                        }
                    }

                    if customImageData != nil {
                        Button(tr("Remove cover", "Cover entfernen"), role: .destructive) {
                            customImageData = nil
                            selectedPhoto = nil
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("AzuraCast API format:", "AzuraCast API-Format:"))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text(verbatim: "https://your-domain.com/api/nowplaying/station_shortcode")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Supported formats", "Unterstützte Formate"))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text("HLS, MP3, AAC")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Why HTTPS only?", "Warum nur HTTPS?"))
                                .font(.caption.bold())
                                .foregroundStyle(.primary)
                            Text(tr(
                                "HTTP streams are not reliably supported due to protocol incompatibilities (e.g. ICY/Icecast). HTTPS ensures stable playback for both public stations and AzuraCast.",
                                "HTTP-Streams werden aufgrund von Protokoll-Inkompatibilitäten (z.B. ICY/Icecast) nicht zuverlässig unterstützt. HTTPS gewährleistet stabile Wiedergabe für öffentliche Sender und AzuraCast."))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing
                             ? tr("Edit Station", "Sender bearbeiten")
                             : tr("Add Station", "Sender hinzufügen"))
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
                    .disabled(streamURL.isEmpty)
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
            .frame(minHeight: hSize == .regular ? 620 : nil)
        }
    }

    private func derivedAPIURL(from streamURL: String) -> String? {
        guard let url = URL(string: streamURL),
              let scheme = url.scheme,
              let host = url.host else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        if let listenIdx = components.firstIndex(of: "listen"), listenIdx + 1 < components.count {
            let stationName = components[listenIdx + 1]
            return "\(scheme)://\(host)/api/nowplaying/\(stationName)"
        }
        if let hlsIdx = components.firstIndex(of: "hls"), hlsIdx + 1 < components.count {
            let stationName = components[hlsIdx + 1]
            return "\(scheme)://\(host)/api/nowplaying/\(stationName)"
        }
        return nil
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
