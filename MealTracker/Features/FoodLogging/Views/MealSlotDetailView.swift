import SwiftUI
import SwiftData

struct MealSlotDetailView: View {
    let mealSlot: MealSlotConfig
    let date: Date
    @Query private var entries: [LoggedEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingFood = false
    @State private var editingEntry: LoggedEntry?

    init(mealSlot: MealSlotConfig, date: Date) {
        self.mealSlot = mealSlot
        self.date = date
        let slotID = mealSlot.id
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let predicate = #Predicate<LoggedEntry> { entry in
            entry.mealSlot?.id == slotID && entry.date >= startOfDay && entry.date < endOfDay
        }
        _entries = Query(filter: predicate, sort: \LoggedEntry.date)
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// Surfaces which day you're logging into while backfilling a past/future day, so it's
    /// clear this isn't logging against real "now".
    private var navigationTitleText: String {
        Calendar.current.isDateInToday(date)
            ? mealSlot.name
            : "\(mealSlot.name) · \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("No food logged yet.")
                        .font(.manrope(14, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
                ForEach(entries) { entry in
                    entryRow(entry)
                }
            } header: {
                Text("\(Int(totalCalories)) CALORIES LOGGED")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardAccent)
            }
        }
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            addFoodButton
        }
        .sheet(isPresented: $isAddingFood) {
            FoodLoggingFlowView(initialSlot: mealSlot, date: date)
        }
        .sheet(item: $editingEntry) { entry in
            EditLoggedEntryView(entry: entry)
        }
    }

    private func entryRow(_ entry: LoggedEntry) -> some View {
        Button {
            editingEntry = entry
        } label: {
            HStack(spacing: 12) {
                FoodThumbnailView(
                    urlString: entry.foodItem?.imageURLString,
                    cornerRadius: 12,
                    placeholderColor: .dashboardBarTrack,
                    size: 40
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.foodItem?.name ?? "Unknown Food")
                        .font(.manrope(14, weight: .semibold))
                        .foregroundStyle(Color.dashboardInk)
                    Text("\(entry.quantity, specifier: "%.2f") × \(entry.foodItem?.servingSizeDescription ?? "") — \(Int(entry.calories)) cal")
                        .font(.manrope(11.5, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        // Spelled out rather than `.onDelete` so the button can carry a tint. The destructive
        // role doesn't win over an inherited tint: `MainTabView` tints the whole app with
        // `dashboardAccent`, which reaches down here and paints Delete green in both
        // appearances unless red is pinned explicitly.
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    private func delete(_ entry: LoggedEntry) {
        modelContext.delete(entry)
        try? modelContext.save()
    }

    private var addFoodButton: some View {
        FloatingAddButton(accessibilityLabel: "Add Food") { isAddingFood = true }
    }
}
