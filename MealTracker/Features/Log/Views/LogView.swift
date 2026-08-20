import SwiftUI
import SwiftData
import WidgetKit

/// The "Log" tab: everything you actually put into a day — food, water, fasting — on its own
/// page. These three cards used to sit under the Dashboard's rings and macro breakdown, which
/// made Today a long scroll mixing "how am I doing" with "here's what I ate". The date is shared
/// with the Dashboard (owned by `MainTabView`), so browsing to a past day on Today and switching
/// here logs into that same day.
struct LogView: View {
    let profile: UserProfile
    /// Shared with the Today tab — see `DayContext`.
    @Bindable var dayContext: DayContext

    @Query(sort: \MealSlotConfig.sortOrder) private var allMealSlots: [MealSlotConfig]
    @Query(sort: \LoggedEntry.date) private var allEntries: [LoggedEntry]
    /// Water is scoped by the query itself — `WaterLogEntry.profile` is a single hop, which
    /// SwiftData can express. `LoggedEntry` reaches its profile through `mealSlot`, and a
    /// two-relationship predicate fails at fetch time ("Unsupported function expression"), so
    /// that one is filtered in Swift — once per render, in `body`.
    @Query private var profileWaterEntries: [WaterLogEntry]
    @State private var path = NavigationPath()
    @State private var isShowingMonthCalendar = false
    @State private var isAddingFood = false

    init(profile: UserProfile, dayContext: DayContext) {
        self.profile = profile
        self._dayContext = Bindable(dayContext)
        let profileID = profile.id
        _profileWaterEntries = Query(
            filter: #Predicate<WaterLogEntry> { $0.profile?.id == profileID },
            sort: \WaterLogEntry.date
        )
    }

    /// Read/write shortcut for `dayContext.selectedDate`, so the rest of this view reads the way
    /// it did when the date was local state.
    private var selectedDate: Date {
        get { dayContext.selectedDate }
        nonmutating set { dayContext.selectedDate = newValue }
    }

    private var mealSlots: [MealSlotConfig] {
        allMealSlots.filter { $0.isEnabled && $0.profile?.id == profile.id }
    }

    /// See `DashboardView` for why this filter lives in Swift rather than in the query.
    private var profileEntries: [LoggedEntry] {
        allEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    private var selectedDayWaterEntries: [WaterLogEntry] {
        profileWaterEntries.filter { $0.date >= selectedDate.startOfDay && $0.date < selectedDate.endOfDay }
    }

    private func summary(for dayEntries: [LoggedEntry]) -> DashboardViewModel {
        DashboardViewModel(
            profile: profile,
            todaysEntries: dayEntries,
            weekday: Calendar.current.component(.weekday, from: selectedDate)
        )
    }

    /// Which slot the quick-add button starts on — a guess from the clock, correctable in the
    /// sheet itself. Nil only when every slot has been disabled.
    private var quickAddSlot: MealSlotConfig? {
        MealSlotSuggestion.suggestedSlot(at: Date(), from: mealSlots)
    }

    private var headingText: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        // Walked once per render and handed down — see the same note in `DashboardView`.
        let entries = profileEntries
        let selectedDayEntries = entries.filter { $0.date >= selectedDate.startOfDay && $0.date < selectedDate.endOfDay }
        let summary = summary(for: selectedDayEntries)

        return NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    header

                    LoggedMealsCardView(
                        mealSlots: mealSlots,
                        selectedDayEntries: selectedDayEntries,
                        totalCalories: summary.consumedCalories,
                        calorieTarget: summary.calorieTarget,
                        isToday: Calendar.current.isDateInToday(selectedDate)
                    )
                    .padding(.horizontal, 18)

                    if profile.isWaterTrackingEnabled {
                        WaterCardView(profile: profile, entries: selectedDayWaterEntries, date: selectedDate)
                            .padding(.horizontal, 18)
                    }

                    // Today only — a running fast is a right-now state, not something to browse
                    // a past day for.
                    if profile.isFastingTimerEnabled, Calendar.current.isDateInToday(selectedDate) {
                        FastingCardView(profile: profile)
                            .padding(.horizontal, 18)
                    }
                }
                // Deep enough that the last card can still be scrolled clear of the quick-add
                // button sitting over it.
                .padding(.bottom, 88)
            }
            .background(Color.dashboardCanvas)
            .overlay(alignment: .bottomTrailing) {
                if quickAddSlot != nil {
                    FloatingAddButton(accessibilityLabel: "Log Food") { isAddingFood = true }
                }
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Only the background is hidden — never `.toolbar(.hidden, for: .navigationBar)`,
            // which is what this view originally copied from the Dashboard. Toggling the bar's
            // visibility inside a TabView's per-tab `NavigationStack` replays its hide animation
            // on every tab re-selection, producing a stutter on each switch (see
            // https://developer.apple.com/forums/thread/758923); `ChartsView` was moved off that
            // pattern for the same reason in eaf44de.
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: MealSlotConfig.self) { slot in
                MealSlotDetailView(mealSlot: slot, date: selectedDate)
            }
            .sheet(isPresented: $isAddingFood) {
                if let quickAddSlot {
                    FoodLoggingFlowView(initialSlot: quickAddSlot, date: selectedDate, slotOptions: mealSlots)
                }
            }
            .sheet(isPresented: $isShowingMonthCalendar) {
                MonthCalendarView(
                    selectedDate: $dayContext.selectedDate,
                    profile: profile,
                    daysWithEntries: DayProgressCalculator.daysWithEntries(entries)
                )
            }
        }
    }

    /// The day being logged into, plus a way to change it without going back to Today for the
    /// week strip — the calendar button is the same sheet that header uses.
    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                Text(headingText)
                    .font(.archivo(30, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Spacer()
                Button {
                    isShowingMonthCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.dashboardAccent)
                        .frame(width: 38, height: 38)
                        .background(Color.dashboardCard, in: Circle())
                }
                .accessibilityLabel("Choose Date")
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Rectangle()
                .fill(Color.dashboardDivider)
                .frame(height: 1)
        }
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
