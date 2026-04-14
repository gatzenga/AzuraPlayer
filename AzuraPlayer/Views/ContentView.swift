import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State private var selectedTab = 0
    @State private var showPlayer = false
    @AppStorage("appAppearance") private var appAppearance = "system"
    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var preferredScheme: ColorScheme? {
        switch appAppearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    StationListView()
                        .tabItem { Label("Home", systemImage: "house.fill") }
                        .tag(0)
                    PlaybackHistoryView()
                        .tabItem { Label(tr("History", "Verlauf"), systemImage: "clock.fill") }
                        .tag(1)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                        .tag(2)
                }
                .tint(accentColor)
                .preferredColorScheme(preferredScheme)

                // iPhone: dynamisches Padding via GeometryReader (unverändert)
                if player.currentStation != nil && !isRegularWidth {
                    VStack {
                        Spacer()
                        PlayerBarView()
                            .padding(.horizontal, 16)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 49 + 8)
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
        }
        // iPad: safeAreaInset außerhalb des GeometryReaders –
        // schiebt die TabBar automatisch nach oben, MiniPlayer sitzt ganz unten
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if player.currentStation != nil && isRegularWidth {
                PlayerBarView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showPlayer = true
                        }
                    }
            }
        }
        // iPhone + iPad: identisches Sheet-Verhalten
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
