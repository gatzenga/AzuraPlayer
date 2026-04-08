import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService

    @State private var selectedTab = 0
    @State private var showPlayer = false
    @AppStorage("isDarkModeEnabled") private var isDarkModeEnabled = false
    @AppStorage("themeColor") private var themeColorName = "blue"
    @AppStorage("appLanguage") private var lang = "en"

    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                StationListView()
                    .tabItem { Label("Home", systemImage: "house.fill") }
                    .tag(0)

                PlaybackHistoryView()
                    .tabItem { Label(tr("History", "Verlauf", lang), systemImage: "clock.fill") }
                    .tag(1)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(2)
            }
            .tint(accentColor)
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
                .tint(accentColor)
                .id(showPlayer)
        }
    }
}
