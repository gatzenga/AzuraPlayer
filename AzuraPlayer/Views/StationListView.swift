import SwiftUI

struct StationListView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService
    @AppStorage("appLanguage") private var lang = "en"
    @AppStorage("themeColor") private var themeColorName = "blue"

    @State private var isReordering = false
    @State private var showAddStation = false
    @State private var editingStation: RadioStation? = nil
    @State private var stationToDelete: RadioStation? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.stations) { station in
                    HStack(spacing: 0) {
                        StationRowView(
                            station: station,
                            isPlaying: player.currentStation?.id == station.id && player.isPlaying
                        )

                        if isReordering {
                            Button {
                                stationToDelete = station
                            } label: {
                                Image(systemName: "trash.fill")
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .padding(9)
                                    .background(.red, in: Circle())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isReordering else { return }
                        player.play(station: station)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !isReordering {
                            Button {
                                editingStation = station
                            } label: {
                                Label(tr("Edit", "Bearbeiten", lang), systemImage: "pencil")
                            }
                            .tint(AppTheme.color(for: themeColorName))
                        }
                    }
                    .deleteDisabled(true)
                    .listRowBackground(Color.clear)
                }
                .onMove { from, to in
                    store.move(from: from, to: to)
                }

                Color.clear
                    .frame(height: player.currentStation != nil ? 90 : 0)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .navigationTitle(tr("Stations", "Sender", lang))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isReordering {
                        Button {
                            withAnimation { isReordering = false }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    } else {
                        Button {
                            withAnimation { isReordering = true }
                        } label: {
                            Text(tr("Edit", "Bearbeiten", lang))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isReordering {
                        Button {
                            showAddStation = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                        }
                    }
                }
            }
            .alert(
                tr("Delete Station?", "Sender löschen?", lang),
                isPresented: Binding(
                    get: { stationToDelete != nil },
                    set: { if !$0 { stationToDelete = nil } }
                ),
                presenting: stationToDelete
            ) { station in
                Button(tr("Delete", "Löschen", lang), role: .destructive) {
                    store.delete(station: station)
                    if player.currentStation?.id == station.id {
                        player.stop()
                    }
                    stationToDelete = nil
                }
                Button(tr("Cancel", "Abbrechen", lang), role: .cancel) {
                    stationToDelete = nil
                }
            } message: { station in
                Text(tr(
                    "Do you really want to remove '\(station.displayName)'?",
                    "Möchten Sie '\(station.displayName)' wirklich entfernen?",
                    lang
                ))
            }
            .sheet(isPresented: $showAddStation) {
                AddEditStationView(store: store)
            }
            .sheet(item: $editingStation) { station in
                AddEditStationView(store: store, editStation: station)
            }
        }
    }
}
