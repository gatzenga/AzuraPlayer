import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService

    @State private var selectedTab = 0
    @State private var showPlayer = false
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false

    private let accentBlue = Color(red: 0.0, green: 0.48, blue: 1.0)

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                StationListView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(1)
            }
            .tint(accentBlue)
            .preferredColorScheme(isDarkModeEnabled ? .dark : .light)

            if player.currentStation != nil {
                VStack {
                    Spacer()
                    PlayerBarView()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 95)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showPlayer = true
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .presentationDetents([.large])
                .presentationBackgroundInteraction(.enabled)
                .presentationCornerRadius(24)
                .id(showPlayer)
        }
    }
}
