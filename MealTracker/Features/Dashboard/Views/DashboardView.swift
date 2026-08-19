import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    let profile: UserProfile
    /// Changes each time the already-active "Today" tab is tapped again — see `MainTabView`.
    let goToTodayTrigger: UUID

    @Query(sort: \MealSlotConfig.sortOrder) private var allMealSlots: [MealSlotConfig]
    @Query(sort: \LoggedEntry.date) private var allEntries: [LoggedEntry]
    @State private var path = NavigationPath()
    @State private var selectedDate = Date().startOfDay
    @State private var isShowingMonthCalendar = false
    @Environment(\.scenePhase) private var scenePhase
    /// Persisted (not `@State`) so a cold launch on a new calendar day can be detected —
    /// `@State` would already be gone by the time a fresh launch re-creates this view.
    @AppStorage("lastActiveDayStart") private var lastActiveDayStart: Double = 0

    private var mealSlots: [MealSlotConfig] {
        allMealSlots.filter { $0.isEnabled && $0.profile?.id == profile.id }
    }

    /// All of this profile's entries, unfiltered by date — same "query everything, filter in
    /// Swift" pattern `ChartsView` already uses, needed since a SwiftData `@Query` predicate
    /// can't be mutated after `init` to follow a changing `selectedDate`.
    private var profileEntries: [LoggedEntry] {
        allEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    private var selectedDayEntries: [LoggedEntry] {
        profileEntries.filter { $0.date >= selectedDate.startOfDay && $0.date < selectedDate.endOfDay }
    }

    private var summary: DashboardViewModel {
        DashboardViewModel(
            profile: profile,
            todaysEntries: selectedDayEntries,
            weekday: Calendar.current.component(.weekday, from: selectedDate)
        )
    }

    /// Oldest to newest, ending on the viewed day — feeds `DailyOverviewCardView`'s 7-day strip.
    private var recentDayProgress: [DayProgress] {
        (0..<7).reversed().map { offset in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
            return DayProgressCalculator.dayProgress(for: day, profile: profile, entries: profileEntries)
        }
    }

    private var navigationTitleText: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    WeekStripView(
                        selectedDate: $selectedDate,
                        profile: profile,
                        entries: profileEntries,
                        onTapCalendar: { isShowingMonthCalendar = true }
                    )

                    DailyOverviewCardView(summary: summary, recentDayProgress: recentDayProgress, selectedDate: selectedDate)
                        .padding(.horizontal, 18)

                    MacroBreakdownView(summary: summary)
                        .padding(.horizontal, 18)

                    LoggedMealsCardView(
                        mealSlots: mealSlots,
                        selectedDayEntries: selectedDayEntries,
                        totalCalories: summary.consumedCalories,
                        calorieTarget: summary.calorieTarget,
                        isToday: Calendar.current.isDateInToday(selectedDate)
                    )
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
            .background(Color.dashboardCanvas)
            // Title kept (but not shown — see below) purely so a pushed `MealSlotDetailView`
            // still gets a sensible default back-button label; the visible header is
            // `WeekStripView`'s own big date heading instead, which now also hosts the calendar
            // button that used to live here as a toolbar item. Showing both was a duplicated date.
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MealSlotConfig.self) { slot in
                MealSlotDetailView(mealSlot: slot, date: selectedDate)
            }
            .sheet(isPresented: $isShowingMonthCalendar) {
                MonthCalendarView(selectedDate: $selectedDate, profile: profile, entries: profileEntries)
            }
            .onAppear {
                writeWidgetSnapshot()
                resetToTodayIfNewDay()
            }
            .onChange(of: selectedDayEntries) { _, _ in writeWidgetSnapshot() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { resetToTodayIfNewDay() }
            }
            .onChange(of: goToTodayTrigger) { _, _ in goToToday() }
        }
    }

    /// The widget extension can't share this app's live SwiftData container, so every time
    /// Today's numbers change we hand it a small snapshot through the shared App Group instead
    /// and nudge WidgetKit to redraw immediately rather than waiting for its own refresh policy.
    private func writeWidgetSnapshot() {
        // Browsing a past/future day must never overwrite the home-screen widget with stale
        // data — safe to skip here because logging always writes against the *viewed* date
        // (see date-threading through AddFoodView etc.), so today's entries only ever change
        // while today is actually the selected day.
        guard Calendar.current.isDateInToday(selectedDate) else { return }
        let macros = summary.macroTargets
        let snapshot = DashboardSnapshot(
            consumedCalories: summary.consumedCalories,
            targetCalories: summary.calorieTarget,
            consumedProtein: summary.consumedProtein,
            targetProtein: macros.proteinGrams,
            consumedCarbs: summary.consumedCarbs,
            targetCarbs: macros.carbGrams,
            consumedFat: summary.consumedFat,
            targetFat: macros.fatGrams,
            cyclingDeltaToday: summary.calorieCyclingDeltaToday,
            updatedAt: Date()
        )
        snapshot.save()
        WidgetCenter.shared.reloadTimelines(ofKind: "MealTrackerCalorieWidget")
    }

    /// Pops any pushed meal slot detail first; only jumps the date once the stack is already at
    /// the list. A user drilled into a detail screen on a past day thus needs two re-taps of the
    /// "Today" tab to land on today — one to back out, one to jump the date.
    private func goToToday() {
        withAnimation {
            if !path.isEmpty {
                path = NavigationPath()
            } else {
                selectedDate = Date().startOfDay
            }
        }
    }

    /// Snaps back to today (and clears any pushed detail) the first time this view becomes
    /// active on a calendar day different from the last one it saw — covers both a cold launch
    /// days later and a resume from background after being left open overnight.
    private func resetToTodayIfNewDay() {
        let today = Date().startOfDay
        let lastActiveDay = lastActiveDayStart == 0 ? nil : Date(timeIntervalSince1970: lastActiveDayStart).startOfDay
        if lastActiveDay != today {
            selectedDate = today
            path = NavigationPath()
        }
        lastActiveDayStart = today.timeIntervalSince1970
    }
}

private enum LoggedViewStyle {
    case byMeal, timeline
}

/// "Logged" card — a literal port of the mockup's meal list: an uppercase label + running total
/// above a card of divided rows. Built by hand (rather than a `List` `Section`, which is what the
/// rest of this screen used before this pass) so the card's corner radius, row insets and divider
/// styling can match the mockup exactly instead of iOS's fixed inset-grouped chrome. A header
/// toggle (from the Claude Design "Timeline-first" direction, #1c) switches the body between this
/// by-meal grouping and a chronological thread of the same entries.
private struct LoggedMealsCardView: View {
    let mealSlots: [MealSlotConfig]
    let selectedDayEntries: [LoggedEntry]
    let totalCalories: Double
    let calorieTarget: Double
    let isToday: Bool

    @State private var viewStyle: LoggedViewStyle = .byMeal
    /// Timeline rows edit inline via this sheet, since (unlike `MealSlotGroupedListView`'s rows)
    /// they don't already sit behind a `NavigationLink` push into `MealSlotDetailView`.
    @State private var editingEntry: LoggedEntry?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("LOGGED")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardInkSecondary)
                Spacer()
                LoggedViewToggle(viewStyle: $viewStyle)
                Spacer()
                Text("\(Int(totalCalories)) kcal")
                    .font(.manrope(12, weight: .semibold))
                    .foregroundStyle(Color.dashboardAccent)
            }
            .padding(.horizontal, 4)

            switch viewStyle {
            case .byMeal:
                MealSlotGroupedListView(mealSlots: mealSlots, selectedDayEntries: selectedDayEntries)
            case .timeline:
                EntryTimelineView(
                    entries: selectedDayEntries.sorted { $0.date < $1.date },
                    calorieTarget: calorieTarget,
                    isToday: isToday,
                    onSelectEntry: { editingEntry = $0 }
                )
                .padding(16)
                .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 24))
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditLoggedEntryView(entry: entry)
        }
    }
}

private struct MealSlotGroupedListView: View {
    let mealSlots: [MealSlotConfig]
    let selectedDayEntries: [LoggedEntry]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(mealSlots.enumerated()), id: \.element.id) { index, slot in
                NavigationLink(value: slot) {
                    MealSlotRowView(mealSlot: slot, entries: selectedDayEntries.filter { $0.mealSlot?.id == slot.id })
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 15)

                if index < mealSlots.count - 1 {
                    Rectangle()
                        .fill(Color.dashboardDivider)
                        .frame(height: 1)
                        .padding(.leading, 15 + 44 + 13)
                }
            }
        }
        .padding(.vertical, 6)
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 24))
    }
}

/// Two-icon capsule, styled after the Claude Design mockup's Week/Month segmented toggle (#1e):
/// a tinted track with the active option raised on a card-colored pill.
private struct LoggedViewToggle: View {
    @Binding var viewStyle: LoggedViewStyle

    var body: some View {
        HStack(spacing: 2) {
            option(.byMeal, symbol: "list.bullet")
            option(.timeline, symbol: "clock")
        }
        .padding(3)
        .background(Color.dashboardBarTrack, in: Capsule())
    }

    private func option(_ style: LoggedViewStyle, symbol: String) -> some View {
        let isSelected = viewStyle == style
        return Button {
            viewStyle = style
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? Color.dashboardInk : Color.dashboardInkSecondary)
                .frame(width: 26, height: 22)
                .background(isSelected ? Color.dashboardCard : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
