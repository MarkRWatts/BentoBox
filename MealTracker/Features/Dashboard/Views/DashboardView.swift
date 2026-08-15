import SwiftUI
import SwiftData

struct DashboardView: View {
    let profile: UserProfile

    @Query(sort: \MealSlotConfig.sortOrder) private var allMealSlots: [MealSlotConfig]
    @Query private var todaysEntries: [LoggedEntry]

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
        DashboardViewModel(profile: profile, todaysEntries: todaysEntries)
    }

    var body: some View {
        NavigationStack {
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
        }
    }
}
