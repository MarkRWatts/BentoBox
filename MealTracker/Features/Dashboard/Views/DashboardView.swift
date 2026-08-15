import SwiftUI
import SwiftData

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
            .task {
                guard profile.useHealthKitEnergyAdjustment else { return }
                activeEnergyBurnedToday = await HealthKitManager.shared.activeEnergyBurnedToday()
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
    private var quickAddButton: some View {
        Menu {
            ForEach(mealSlots) { slot in
                Button(slot.name) { path.append(slot) }
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .padding(20)
        .accessibilityLabel("Log Food")
    }
}
