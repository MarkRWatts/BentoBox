import SwiftUI

struct MainTabView: View {
    let profile: UserProfile

    var body: some View {
        TabView {
            DashboardView(profile: profile)
                .tabItem {
                    Label("Today", systemImage: "chart.pie.fill")
                }

            ChartsView(profile: profile)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView(profile: profile)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
    }
}
