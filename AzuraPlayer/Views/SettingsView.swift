import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var store: StationStore
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("appLanguage") private var lang = "en"
    @AppStorage("themeColor") private var themeColorName = "blue"

    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var pendingImport: [RadioStation]?
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var showExportError = false

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        NavigationStack {
            List {
                Section(tr("Appearance", "Erscheinungsbild", lang)) {
                    Toggle(tr("Enable Dark Mode", "Dark Mode aktivieren", lang), isOn: $isDarkModeEnabled)
                    Text(tr(
                        "When enabled, the app is always shown in dark mode.",
                        "Wenn aktiviert, wird die App immer im Dunklen Modus angezeigt.",
                        lang
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Picker(tr("Language", "Sprache", lang), selection: $lang) {
                        Text("English").tag("en")
                        Text("Deutsch").tag("de")
                    }
                    .id(lang + themeColorName)

                    Picker(tr("Accent Color", "Akzentfarbe", lang), selection: $themeColorName) {
                        ForEach(AppTheme.options, id: \.name) { option in
                            HStack {
                                Circle()
                                    .fill(option.color)
                                    .frame(width: 14, height: 14)
                                Text(lang == "de" ? option.nameDE : option.nameEN)
                            }
                            .tag(option.name)
                        }
                    }
                    .id(themeColorName)
                }

                Section(tr("Stations", "Sender", lang)) {
                    Button {
                        exportStations()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.secondary)
                            Text(tr("Export Stations", "Sender exportieren", lang))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(store.stations.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showImporter = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundStyle(.secondary)
                            Text(tr("Import Stations", "Sender importieren", lang))
                                .foregroundStyle(.primary)
                        }
                    }
                }

                Section(tr("Links & Contact", "Links & Kontakt", lang)) {
                    if let url = URL(string: "https://github.com/gatzenga/AzuraPlayer") {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "chevron.left.forwardslash.chevron.right")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text("GitHub")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let url = URL(string: "https://gatzenga.github.io/AzuraPlayer/privacy.html") {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "hand.raised")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text(tr("Privacy Policy", "Datenschutz", lang))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let url = URL(string: "mailto:kontakt@vkugler.ch") {
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "envelope")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Text(tr("Contact", "Kontakt", lang))
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Info") {
                    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
                    let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
                    Text("AzuraPlayer \(version) (\(build))")
                    Text(tr(
                        "AzuraPlayer is an unofficial app and has no affiliation with AzuraCast or its developers.",
                        "AzuraPlayer ist eine inoffizielle App und steht in keiner Verbindung zu AzuraCast oder dessen Entwicklern.",
                        lang
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Color.clear
                    .frame(height: 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .preferredColorScheme(isDarkModeEnabled ? .dark : .light)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(tr("Settings", "Einstellungen", lang))
            .tint(accentColor)
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
            .alert(
                tr("Import Stations?", "Sender importieren?", lang),
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }
                ),
                presenting: pendingImport
            ) { stations in
                Button(tr("Import", "Importieren", lang)) {
                    store.importStations(stations)
                    pendingImport = nil
                }
                Button(tr("Cancel", "Abbrechen", lang), role: .cancel) {
                    pendingImport = nil
                }
            } message: { stations in
                Text(tr(
                    "Do you really want to import \(stations.count) station(s)?",
                    "Möchtest du \(stations.count) Sender wirklich importieren?",
                    lang
                ))
            }
            .alert(tr("Import failed", "Import fehlgeschlagen", lang), isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importErrorMessage ?? "")
            }
            .alert(tr("Export failed", "Export fehlgeschlagen", lang), isPresented: $showExportError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Export

    private func exportStations() {
        do {
            let data = try JSONEncoder().encode(store.stations)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("AzuraPlayer-Sender")
                .appendingPathExtension("json")
            try data.write(to: url)
            exportURL = url
        } catch {
            print("[SettingsView] Export failed: \(error)")
            showExportError = true
        }
    }

    // MARK: - Import

    private func handleImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([RadioStation].self, from: data)
            let existingURLs = Set(store.stations.map { $0.streamURL })
            let newStations = decoded.filter { !existingURLs.contains($0.streamURL) }
            if newStations.isEmpty {
                importErrorMessage = tr(
                    "All stations already exist in your list.",
                    "Alle Sender sind bereits in deiner Liste vorhanden.",
                    lang
                )
                showImportError = true
            } else {
                pendingImport = newStations
            }
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - Share Sheet

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
