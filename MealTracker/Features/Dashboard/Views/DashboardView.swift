import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    let profile: UserProfile

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

    private var navigationTitleText: String {
        if Calendar.current.isDateInToday(selectedDate) { return "Today" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "Yesterday" }
        return selectedDate.formatted(.dateTime.month(.abbreviated).day())
    }

    /// False whenever there's still something for the "Today" button to do: pop a pushed meal
    /// slot detail, or jump the selected date. True only once both are already settled.
    private var isShowingToday: Bool {
        path.isEmpty && Calendar.current.isDateInToday(selectedDate)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    WeekStripView(selectedDate: $selectedDate, profile: profile, entries: profileEntries)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    CalorieSummaryRingView(summary: summary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                }
                .listRowBackground(Color.clear)

                Section("Macros") {
                    MacroBreakdownView(summary: summary)
                }

                Section("Meals") {
                    ForEach(mealSlots) { slot in
                        NavigationLink(value: slot) {
                            MealSlotRowView(mealSlot: slot, entries: selectedDayEntries.filter { $0.mealSlot?.id == slot.id })
                        }
                    }
                }
            }
            .navigationTitle(navigationTitleText)
            .toolbar {
                if !isShowingToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today", action: goToToday)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingMonthCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Choose Date")
                }
            }
            .navigationDestination(for: MealSlotConfig.self) { slot in
                MealSlotDetailView(mealSlot: slot, date: selectedDate, onGoToToday: goToToday)
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
            .overlay(alignment: .bottomTrailing) {
                quickAddButton
            }
        }
    }

    /// The plan's "primary custom-glass moment" — a floating action button people reach for
    /// constantly deserves the deliberate Liquid Glass treatment, unlike the dashboard's data
    /// cards. Kept to a plain Menu (system glass chrome) rather than a custom
    /// GlassEffectContainer morph animation: a morph is a bigger, higher-risk lift to get right
    /// without a device to check the animation against, and a plain menu already delivers the
    /// "reach a meal slot in one tap from anywhere on Today" goal.
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
    /// the list. A user drilled into a detail screen on a past day thus needs two taps — one to
    /// back out, one to actually land on today — mirroring the standard "tap twice" tab-root idiom.
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

    private var quickAddButton: some View {
        Menu {
            ForEach(mealSlots) { slot in
                Button(slot.name) { path.append(slot) }
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        // `.brandForest` rather than `.accentColor` — same dark-mode contrast issue as the
        // Snack icon: accentColor brightens in dark mode, which combined with the glass
        // material's translucency left the white "+" too low-contrast to read clearly.
        .glassEffect(.regular.tint(.brandForest).interactive(), in: Circle())
        .padding(20)
        .accessibilityLabel("Log Food")
    }
}
