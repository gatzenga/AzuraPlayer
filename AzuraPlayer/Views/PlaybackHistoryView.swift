import SwiftUI

struct PlaybackHistoryView: View {
    @ObservedObject private var historyStore = PlaybackHistoryStore.shared

    @AppStorage("themeColor") private var themeColorName = "blue"
    @State private var showDeleteConfirmation = false
    @State private var selectedEntry: PlaybackEntry? = nil

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(historyStore.entries) { entry in
                    PlaybackEntryRow(entry: entry) {
                        selectedEntry = entry
                    }
                    .listRowBackground(Color.clear)
                }

                Color.clear
                    .frame(height: 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle(tr("Playback History", "Wiedergabeverlauf"))
            .toolbar {
                if !historyStore.entries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(tr("Delete", "Löschen")) {
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .alert(
                tr("Delete History?", "Verlauf löschen?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(tr("Delete All", "Alle löschen"), role: .destructive) {
                    historyStore.clearAll()
                }
                Button(tr("Cancel", "Abbrechen"), role: .cancel) { }
            } message: {
                Text(tr(
                    "This action cannot be undone.",
                    "Diese Aktion kann nicht rückgängig gemacht werden."
                ))
            }
            .overlay {
                if historyStore.entries.isEmpty {
                    ContentUnavailableView(
                        tr("No Entries Yet", "Noch keine Einträge"),
                        systemImage: "music.note.list",
                        description: Text(tr(
                            "Songs will appear here once a stream is playing.",
                            "Hier erscheinen Songs, sobald ein Stream läuft."
                        ))
                    )
                }
            }
            .sheet(item: $selectedEntry) { entry in
                PlaybackEntryDetailView(entry: entry)
                    .tint(accentColor)
            }
            .tint(accentColor)
        }
    }
}

// MARK: - Entry Row

private struct PlaybackEntryRow: View {
    let entry: PlaybackEntry
    let onShowFull: () -> Void



    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var timeString: String {
        PlaybackEntryRow.timeFormatter.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(spacing: 12) {

            // Album-Art
            Group {
                if let urlString = entry.artworkURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            artworkPlaceholder
                        }
                    }
                } else {
                    artworkPlaceholder
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Song-Info
            VStack(alignment: .leading, spacing: 3) {
                if entry.artist.isEmpty {
                    Text(entry.songTitle)
                        .font(.body)
                        .lineLimit(1)
                } else {
                    Text("\(entry.artist) – \(entry.songTitle)")
                        .font(.body)
                        .lineLimit(1)
                }
                Text(entry.stationName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Uhrzeit
            Text(timeString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                onShowFull()
            } label: {
                Label(tr("Show Full", "Vollständig anzeigen"), systemImage: "text.magnifyingglass")
            }

            Divider()

            Button {
                UIPasteboard.general.string = entry.songTitle
            } label: {
                Label(tr("Copy Title", "Titel kopieren"), systemImage: "music.note")
            }

            if !entry.artist.isEmpty {
                Button {
                    UIPasteboard.general.string = entry.artist
                } label: {
                    Label(tr("Copy Artist", "Künstler kopieren"), systemImage: "person.fill")
                }
            }
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color(UIColor.systemGray5))
            .overlay {
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Entry Detail View

struct PlaybackEntryDetailView: View {
    let entry: PlaybackEntry

    @Environment(\.dismiss) private var dismiss

    @AppStorage("themeColor") private var themeColorName = "blue"

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var dateTimeString: String {
        PlaybackEntryDetailView.dateTimeFormatter.string(from: entry.timestamp)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {

                // Artwork
                Group {
                    if let urlString = entry.artworkURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                artworkPlaceholder
                            }
                        }
                    } else {
                        artworkPlaceholder
                    }
                }
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
                .padding(.top, 12)

                // Song-Info
                VStack(spacing: 6) {
                    if !entry.artist.isEmpty {
                        Text(entry.artist)
                            .font(.title3.bold())
                            .multilineTextAlignment(.center)
                    }

                    Text(entry.songTitle)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(entry.artist.isEmpty ? .primary : .secondary)

                    Text(entry.stationName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.top, 2)

                    Text(dateTimeString)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                Divider()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // Kopier-Buttons
                VStack(spacing: 8) {
                    CopyButton(
                        label: tr("Copy Title", "Titel kopieren"),
                        icon: "music.note",
                        value: entry.songTitle,
                        accentColor: accentColor
                    )

                    if !entry.artist.isEmpty {
                        CopyButton(
                            label: tr("Copy Artist", "Künstler kopieren"),
                            icon: "person.fill",
                            value: entry.artist,
                            accentColor: accentColor
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Close", "Schließen")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(UIColor.systemGray5))
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
    }
}

// MARK: - Copy Button

private struct CopyButton: View {
    let label: String
    let icon: String
    let value: String
    let accentColor: Color


    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = value
            withAnimation { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { copied = false }
            }
        } label: {
            HStack {
                Image(systemName: copied ? "checkmark" : icon)
                    .frame(width: 20)
                Text(copied ? tr("Copied!", "Kopiert!") : label)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(copied ? accentColor.opacity(0.15) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .foregroundStyle(accentColor)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}
