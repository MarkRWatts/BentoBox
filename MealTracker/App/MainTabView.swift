import SwiftUI

private enum MainTab: Hashable {
    case today, trends, settings
}

struct MainTabView: View {
    let profile: UserProfile
    @State private var selectedTab: MainTab = .today
    /// Bumped whenever the already-active "Today" tab is tapped again, so `DashboardView` can
    /// jump back to today — the standard iOS "tap the current tab to reset" idiom, done here
    /// with a custom `Binding` since `TabView` only calls a plain `@State`'s setter on an actual
    /// selection change, never on a re-tap of the tab you're already on.
    @State private var goToTodayTrigger = UUID()

    private var selection: Binding<MainTab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == .today && selectedTab == .today {
                    goToTodayTrigger = UUID()
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: selection) {
            DashboardView(profile: profile, goToTodayTrigger: goToTodayTrigger)
                .tabItem {
                    Label("Today", systemImage: "chart.pie.fill")
                }
                .tag(MainTab.today)

            ChartsView(profile: profile)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(MainTab.trends)

            SettingsView(profile: profile)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(MainTab.settings)
        }
    }
}
