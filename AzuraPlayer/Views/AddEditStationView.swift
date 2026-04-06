import SwiftUI
import PhotosUI

struct AddEditStationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: StationStore

    var editStation: RadioStation?

    @State private var customName: String = ""
    @State private var streamURL: String = ""
    @State private var apiURL: String = ""
    @State private var showSongArt: Bool = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var customImageData: Data?

    var isEditing: Bool { editStation != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Stream-Daten") {
                    TextField("Name (optional – sonst Sendername)", text: $customName)
                        .autocorrectionDisabled()

                    TextField("Stream-URL", text: $streamURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)

                    TextField("API-URL (Now Playing)", text: $apiURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                }

                Section("Cover") {
                    Toggle("Song-Cover anzeigen (statt Senderbild)", isOn: $showSongArt)

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
                            Text(customImageData == nil ? "Custom Cover wählen" : "Cover ändern")
                        }
                    }

                    if customImageData != nil {
                        Button("Cover entfernen", role: .destructive) {
                            customImageData = nil
                            selectedPhoto = nil
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("💡 AzuraCast API-Format:")
                            .font(.caption).bold()
                        Text("https://deine-domain.com/api/nowplaying/station_shortcode")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Sender bearbeiten" : "Sender hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
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

    private func prefill() {
        guard let s = editStation else { return }
        customName = s.customName ?? ""
        streamURL = s.streamURL
        apiURL = s.apiURL
        showSongArt = s.showSongArt
        customImageData = s.customImageData
    }

    private func save() {
        var station = editStation ?? RadioStation(streamURL: streamURL, apiURL: apiURL)
        station.customName = customName.isEmpty ? nil : customName
        station.streamURL = streamURL
        station.apiURL = apiURL
        station.showSongArt = showSongArt
        station.customImageData = customImageData

        if isEditing {
            store.update(station: station)
        } else {
            store.add(station: station)
        }
        dismiss()
    }
}
