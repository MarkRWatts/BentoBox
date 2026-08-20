import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    let profile: UserProfile
    /// Shared with the Log tab, so browsing to a past day here means the Log tab logs into that
    /// same day. See `DayContext` for why this is an object rather than a `@Binding`.
    @Bindable var dayContext: DayContext
    /// Changes each time the already-active "Today" tab is tapped again — see `MainTabView`.
    let goToTodayTrigger: UUID

    @Query(sort: \MealSlotConfig.sortOrder) private var allMealSlots: [MealSlotConfig]
    @Query(sort: \LoggedEntry.date) private var allEntries: [LoggedEntry]
    @State private var path = NavigationPath()
    @State private var isShowingMonthCalendar = false
    @State private var isQuickAddingFood = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    /// Persisted (not `@State`) so a cold launch on a new calendar day can be detected —
    /// `@State` would already be gone by the time a fresh launch re-creates this view.
    @AppStorage("lastActiveDayStart") private var lastActiveDayStart: Double = 0

    /// Read/write shortcut for `dayContext.selectedDate`, so the rest of this view reads the way
    /// it did when the date was local state.
    private var selectedDate: Date {
        get { dayContext.selectedDate }
        nonmutating set { dayContext.selectedDate = newValue }
    }

    private var mealSlots: [MealSlotConfig] {
        allMealSlots.filter { $0.isEnabled && $0.profile?.id == profile.id }
    }

    /// Filtered in Swift rather than by the `@Query`: a SwiftData predicate can't traverse two
    /// relationships (`entry.mealSlot?.profile?.id` fails at fetch with "Unsupported function
    /// expression"), and it can't follow a changing `selectedDate` either. It is therefore
    /// evaluated exactly once per render in `body` and passed down — reading it from each of the
    /// dozen computed properties that need it walked the whole log a dozen times per pass.
    private var profileEntries: [LoggedEntry] {
        allEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    /// Which slot the quick-add button starts on — a guess from the clock, correctable in the
    /// sheet itself. Nil only when every slot has been disabled, in which case there's nothing
    /// to log into and the button is hidden rather than shown broken.
    private var quickAddSlot: MealSlotConfig? {
        MealSlotSuggestion.suggestedSlot(at: Date(), from: mealSlots)
    }

    /// Takes the already-filtered entries so `body` can compute them once; the parameterless
    /// version below is for the occasional non-render caller (widget snapshot, adaptive target).
    private func summary(for entries: [LoggedEntry]) -> DashboardViewModel {
        DashboardViewModel(
            profile: profile,
            todaysEntries: entries.filter { $0.date >= selectedDate.startOfDay && $0.date < selectedDate.endOfDay },
            weekday: Calendar.current.component(.weekday, from: selectedDate)
        )
    }

    private var summary: DashboardViewModel {
        summary(for: profileEntries)
    }

    /// Oldest to newest, ending on the viewed day — feeds `DailyOverviewCardView`'s 7-day strip.
    /// Groups the log once and hands each day only its own entries, rather than having all seven
    /// days each filter the whole thing.
    private func recentDayProgress(from entriesByDay: [Date: [LoggedEntry]]) -> [DayProgress] {
        (0..<7).reversed().map { offset in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: selectedDate) ?? selectedDate
            return DayProgressCalculator.dayProgress(
                for: day,
                profile: profile,
                entries: entriesByDay[day.startOfDay] ?? []
            )
        }
    }

    /// Start-of-day keys for the days whose calories ended up over target — feeds the week
    /// strip's dots. Computed only over days that actually have entries (the dictionary's keys),
    /// not the strip's whole ~2-year scrollable range, since a day with nothing logged can never
    /// be "over".
    private func daysOverTarget(from entriesByDay: [Date: [LoggedEntry]]) -> Set<Date> {
        Set(entriesByDay.compactMap { day, dayEntries in
            let progress = DayProgressCalculator.dayProgress(for: day, profile: profile, entries: dayEntries)
            return progress.caloriesConsumed > progress.caloriesTarget ? day : nil
        })
    }

    private var navigationTitleText: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    var body: some View {
        // The log is walked once here and the results handed down, rather than each card reading
        // the computed properties and re-filtering. SwiftUI evaluates this body several times per
        // tab switch and both tabs re-render on each one, so a filter that costs ~4ms over a
        // year of entries was landing dozens of times per switch.
        let entries = profileEntries
        let entriesByDay = DayProgressCalculator.entriesByDay(entries)
        let daysWithEntries = DayProgressCalculator.daysWithEntries(entries)
        let summary = summary(for: entries)
        // Watched below instead of the day's entries array: comparing that array meant rebuilding
        // it (and so re-filtering the whole log) on every render just to decide whether the
        // widget needed rewriting. The calorie total is already computed here and changes
        // whenever the widget's contents would.
        let consumedToday = summary.consumedCalories

        return NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    WeekStripView(
                        selectedDate: $dayContext.selectedDate,
                        daysWithEntries: daysWithEntries,
                        daysOverTarget: daysOverTarget(from: entriesByDay),
                        onTapCalendar: { isShowingMonthCalendar = true },
                        onTapAvatar: { path.append(SettingsRoute()) }
                    )

                    DailyOverviewCardView(summary: summary, recentDayProgress: recentDayProgress(from: entriesByDay), selectedDate: selectedDate)
                        .padding(.horizontal, 18)

                    MacroBreakdownView(summary: summary)
                        .padding(.horizontal, 18)

                    MicronutrientBreakdownView(summary: summary)
                        .padding(.horizontal, 18)
                        // Deep enough that the last card can still be scrolled clear of the
                        // quick-add button sitting over it.
                        .padding(.bottom, 88)
                }
            }
            .background(Color.dashboardCanvas)
            .swipeBetweenTabs()
            .overlay(alignment: .bottomTrailing) {
                if quickAddSlot != nil {
                    FloatingAddButton(accessibilityLabel: "Log Food") { isQuickAddingFood = true }
                }
            }
            // Title kept (but not shown — see below) purely so a pushed `MealSlotDetailView`
            // still gets a sensible default back-button label; the visible header is
            // `WeekStripView`'s own big date heading instead, which now also hosts the calendar
            // button that used to live here as a toolbar item. Showing both was a duplicated date.
            .navigationTitle(navigationTitleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SettingsRoute.self) { _ in
                SettingsView(profile: profile)
            }
            .sheet(isPresented: $isQuickAddingFood) {
                if let quickAddSlot {
                    FoodLoggingFlowView(initialSlot: quickAddSlot, date: selectedDate, slotOptions: mealSlots)
                }
            }
            .sheet(isPresented: $isShowingMonthCalendar) {
                MonthCalendarView(selectedDate: $dayContext.selectedDate, profile: profile, daysWithEntries: daysWithEntries)
            }
            .onAppear {
                writeWidgetSnapshot()
                resetToTodayIfNewDay()
                recalculateAdaptiveTargetIfNeeded()
            }
            .onChange(of: consumedToday) { _, _ in writeWidgetSnapshot() }
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

    /// Recomputes and caches `profile.adaptiveCalorieTarget` once a week (matching the cadence
    /// `AdaptiveTDEECalculator`'s header describes), never on every render — that's what keeps
    /// the target stable day to day instead of jittering with each new log entry.
    private func recalculateAdaptiveTargetIfNeeded() {
        guard profile.isAdaptiveCalorieTargetEnabled else { return }
        let now = Date()
        if let updatedAt = profile.adaptiveCalorieTargetUpdatedAt, now.timeIntervalSince(updatedAt) < 7 * 24 * 3600 {
            return
        }
        let dailyCalories = Dictionary(grouping: profileEntries, by: { $0.date.startOfDay })
            .mapValues { $0.reduce(0) { $0 + $1.calories } }
        let weights = profile.weightHistory.map { (date: $0.date.startOfDay, weightKG: $0.weightKG) }
        guard let result = AdaptiveTDEECalculator.estimate(dailyCalories: dailyCalories, weightEntries: weights, referenceDate: now) else {
            return
        }
        profile.adaptiveCalorieTarget = result.tdee
        profile.adaptiveCalorieTargetUpdatedAt = now
        try? modelContext.save()
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
