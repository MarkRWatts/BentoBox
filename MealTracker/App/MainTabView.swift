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

    /// Moves the selection by a delta, for the swipe gesture each tab's root content hosts.
    private func switchTab(by delta: Int) {
        guard let currentIndex = MainTab.allCases.firstIndex(of: selectedTab) else { return }
        let newIndex = currentIndex + delta
        guard MainTab.allCases.indices.contains(newIndex) else { return }
        selection.wrappedValue = MainTab.allCases[newIndex]
    }

    var body: some View {
        TabView(selection: selection) {
            DashboardView(profile: profile, dayContext: dayContext, goToTodayTrigger: goToTodayTrigger)
                .tabItem {
                    Label("Today", systemImage: "chart.pie.fill")
                }
                .tag(MainTab.today)

            LogView(profile: profile, dayContext: dayContext)
                .tabItem {
                    Label("Log", systemImage: "fork.knife")
                }
                .tag(MainTab.log)

            ChartsView(profile: profile)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(MainTab.trends)
        }
        // Matches the Dashboard day strip's "logged" dots (`Color.dashboardAccent`) rather than
        // the app-wide `accentColor` asset, so the floating tab bar reads as the same mint green
        // used throughout the redesigned screens.
        .tint(Color.dashboardAccent)
        .environment(\.switchTab) { delta in switchTab(by: delta) }
    }
}

private struct SwitchTabKey: EnvironmentKey {
    // `@MainActor` + `@Sendable`: strict concurrency won't accept a bare closure as a static
    // default, and this is only ever read and called from the main actor anyway.
    static let defaultValue: @MainActor @Sendable (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Moves the selected tab by a delta. Injected by `MainTabView` so that the swipe gesture can
    /// live on each tab's *root* content instead of on the tab as a whole — see
    /// `swipeBetweenTabs()`.
    var switchTab: @MainActor @Sendable (Int) -> Void {
        get { self[SwitchTabKey.self] }
        set { self[SwitchTabKey.self] = newValue }
    }
}

extension View {
    /// Swipe left/right to move between tabs, for a tab's root scrolling content.
    ///
    /// A plain bottom TabView has no built-in swipe-between-tabs gesture on iPhone, so it's added
    /// by hand rather than switching to `.tabViewStyle(.page)` (which would replace the native
    /// floating tab bar with page dots). It must not go on the `TabView` itself, where it competes
    /// with the tab bar's own touch handling and can silently eat taps on the tab buttons — and
    /// not on a whole tab either, which is where it was: that kept it alive on *pushed* screens,
    /// so swiping a meal entry to reveal its row actions also flipped to the next tab.
    func swipeBetweenTabs() -> some View {
        modifier(SwipeBetweenTabsModifier())
    }
}

private struct SwipeBetweenTabsModifier: ViewModifier {
    @Environment(\.switchTab) private var switchTab

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 60, coordinateSpace: .local)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical) * 2 else { return }
                    switchTab(horizontal < 0 ? 1 : -1)
                }
        )
    }
}
