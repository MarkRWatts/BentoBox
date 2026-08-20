import SwiftUI

private enum MainTab: Int, Hashable, CaseIterable {
    case today, log, trends
}

struct MainTabView: View {
    let profile: UserProfile
    @State private var selectedTab: MainTab = .today
    /// Bumped whenever the already-active "Today" tab is tapped again, so `DashboardView` can
    /// jump back to today — the standard iOS "tap the current tab to reset" idiom, done here
    /// with a custom `Binding` since `TabView` only calls a plain `@State`'s setter on an actual
    /// selection change, never on a re-tap of the tab you're already on.
    @State private var goToTodayTrigger = UUID()
    /// Shared so the Log tab logs into whichever day Today is showing — the two tabs are one
    /// day's worth of context split across two pages, not two independent screens.
    @State private var dayContext = DayContext()

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

    // A plain bottom TabView has no built-in edge-swipe-between-tabs gesture on iPhone, so it's
    // added by hand here rather than switching to `.tabViewStyle(.page)` (which would replace the
    // native floating tab bar with page dots). Attached to each tab's own content below — never
    // to the `TabView` itself — since a gesture on the container competes with the native tab
    // bar's own touch handling for the tab buttons themselves and can silently eat taps on them.
    private var swipeBetweenTabsGesture: some Gesture {
        DragGesture(minimumDistance: 60, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) * 2 else { return }
                guard let currentIndex = MainTab.allCases.firstIndex(of: selectedTab) else { return }
                let newIndex = horizontal < 0 ? currentIndex + 1 : currentIndex - 1
                guard MainTab.allCases.indices.contains(newIndex) else { return }
                selection.wrappedValue = MainTab.allCases[newIndex]
            }
    }

    var body: some View {
        TabView(selection: selection) {
            DashboardView(profile: profile, dayContext: dayContext, goToTodayTrigger: goToTodayTrigger)
                .simultaneousGesture(swipeBetweenTabsGesture)
                .tabItem {
                    Label("Today", systemImage: "chart.pie.fill")
                }
                .tag(MainTab.today)

            LogView(profile: profile, dayContext: dayContext)
                .simultaneousGesture(swipeBetweenTabsGesture)
                .tabItem {
                    Label("Log", systemImage: "fork.knife")
                }
                .tag(MainTab.log)

            ChartsView(profile: profile)
                .simultaneousGesture(swipeBetweenTabsGesture)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(MainTab.trends)
        }
        // Matches the Dashboard day strip's "logged" dots (`Color.dashboardAccent`) rather than
        // the app-wide `accentColor` asset, so the floating tab bar reads as the same mint green
        // used throughout the redesigned screens.
        .tint(Color.dashboardAccent)
    }
}
