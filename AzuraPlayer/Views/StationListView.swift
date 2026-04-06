import SwiftUI

struct StationListView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService

    @State private var showAddStation = false
    @State private var editingStation: RadioStation? = nil
    @State private var stationToDelete: RadioStation? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.stations) { station in
                    StationRowView(
                        station: station,
                        isPlaying: player.currentStation?.id == station.id && player.isPlaying,
                        isBuffering: player.currentStation?.id == station.id && player.isBuffering
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        player.play(station: station)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            stationToDelete = station
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                        .tint(.red)

                        Button {
                            editingStation = station
                        } label: {
                            Label("Bearbeiten", systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
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
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .navigationTitle("AzuraPlayer")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddStation = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .semibold))
                    }
                }
            }
            .alert(
                "Sender löschen?",
                isPresented: Binding(
                    get: { stationToDelete != nil },
                    set: { if !$0 { stationToDelete = nil } }
                ),
                presenting: stationToDelete
            ) { station in
                Button("Löschen", role: .destructive) {
                    store.delete(station: station)
                    if player.currentStation?.id == station.id {
                        player.stop()
                    }
                    stationToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    stationToDelete = nil
                }
            } message: { station in
                Text("Möchten Sie '\(station.displayName)' wirklich entfernen?")
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

