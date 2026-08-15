import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    let profile: UserProfile

    @Query(sort: \MealSlotConfig.sortOrder) private var allMealSlots: [MealSlotConfig]
    @Query private var todaysEntries: [LoggedEntry]
    @State private var activeEnergyBurnedToday: Double?
    @State private var path = NavigationPath()

    init(profile: UserProfile) {
        self.profile = profile
        let startOfDay = Date().startOfDay
        let endOfDay = Date().endOfDay
        let predicate = #Predicate<LoggedEntry> { entry in
            entry.date >= startOfDay && entry.date < endOfDay
        }
        _todaysEntries = Query(filter: predicate, sort: \LoggedEntry.date)
    }

    private var mealSlots: [MealSlotConfig] {
        allMealSlots.filter { $0.isEnabled && $0.profile?.id == profile.id }
    }

    private var summary: DashboardViewModel {
        DashboardViewModel(profile: profile, todaysEntries: todaysEntries, activeEnergyBurnedToday: activeEnergyBurnedToday)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    CalorieSummaryRingView(summary: summary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                }
                .listRowBackground(Color.clear)

                Section("Macros") {
                    MacroBreakdownView(summary: summary)
                }

                Section("Today's Meals") {
                    ForEach(mealSlots) { slot in
                        NavigationLink(value: slot) {
                            MealSlotRowView(mealSlot: slot, entries: todaysEntries.filter { $0.mealSlot?.id == slot.id })
                        }
                    }
                }
            }
            .navigationTitle("Today")
            .navigationDestination(for: MealSlotConfig.self) { slot in
                MealSlotDetailView(mealSlot: slot)
            }
            .onAppear {
                Task { await refreshHealthKitEnergy() }
                writeWidgetSnapshot()
            }
            .onChange(of: todaysEntries) { _, _ in writeWidgetSnapshot() }
            .onChange(of: activeEnergyBurnedToday) { _, _ in writeWidgetSnapshot() }
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
    /// Runs on every appearance (not just the first) so turning HealthKit adjustment on from
    /// Settings takes effect the next time you're back on Today, and so today's active energy
    /// stays current as it changes through the day — a one-shot `.task` only ever ran once per
    /// view lifetime, which made the toggle look like it did nothing if flipped after Today had
    /// already appeared once.
    private func refreshHealthKitEnergy() async {
        guard profile.useHealthKitEnergyAdjustment else {
            activeEnergyBurnedToday = nil
            return
        }
        activeEnergyBurnedToday = await HealthKitManager.shared.activeEnergyBurnedToday()
    }

    /// The widget extension can't share this app's live SwiftData container, so every time
    /// Today's numbers change we hand it a small snapshot through the shared App Group instead
    /// and nudge WidgetKit to redraw immediately rather than waiting for its own refresh policy.
    private func writeWidgetSnapshot() {
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
        .glassEffect(.regular.tint(.accentColor).interactive(), in: Circle())
        .padding(20)
        .accessibilityLabel("Log Food")
    }
}
