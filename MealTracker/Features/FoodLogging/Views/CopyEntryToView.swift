import SwiftUI
import SwiftData

/// Copies one logged entry to another meal, another day, or both — the fast path for "I ate that
/// again", reached by swiping an entry right in `MealSlotDetailView`.
///
/// The copy shares the original's `FoodItem` rather than duplicating it, matching how
/// `CopyFromPreviousDayView` and recent-food logging already work: nutrition edits detach a
/// private copy at the point of editing, so sharing here can't retroactively rewrite either day.
struct CopyEntryToView: View {
    let entry: LoggedEntry
    var onCompleted: () -> Void

    @Query(sort: \MealSlotConfig.sortOrder) private var allSlots: [MealSlotConfig]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var targetSlotID: UUID?
    @State private var targetDate: Date

    init(entry: LoggedEntry, onCompleted: @escaping () -> Void) {
        self.entry = entry
        self.onCompleted = onCompleted
        _targetSlotID = State(initialValue: entry.mealSlot?.id)
        _targetDate = State(initialValue: entry.date.startOfDay)
    }

    private var slots: [MealSlotConfig] {
        allSlots.filter { $0.isEnabled && $0.profile?.id == entry.mealSlot?.profile?.id }
    }

    private var targetSlot: MealSlotConfig? {
        slots.first { $0.id == targetSlotID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Copy") {
                    LabeledContent(entry.foodItem?.name ?? "Unknown Food") {
                        Text("\(entry.quantity, specifier: "%.2f") × \(Int(entry.calories)) cal")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("To") {
                    Picker("Meal", selection: $targetSlotID) {
                        ForEach(slots) { slot in
                            Text(slot.disambiguatedName(among: slots)).tag(UUID?.some(slot.id))
                        }
                    }
                    DatePicker("Day", selection: $targetDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Copy To")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy") { copy() }
                        .disabled(targetSlot == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func copy() {
        guard let targetSlot else { return }
        // Real "now" on the target day, not the original's time — same rule the rest of logging
        // follows, so backfilling yesterday lands at a plausible hour rather than at midnight.
        // `lastUsedAt` is bumped for the same reason `CopyFromPreviousDayView` bumps it: this is
        // a fresh use as far as "Recent" is concerned.
        entry.foodItem?.lastUsedAt = Date()
        let copy = LoggedEntry(
            date: targetDate.atCurrentTimeOfDay,
            quantity: entry.quantity,
            mealSlotNameSnapshot: targetSlot.name,
            foodItem: entry.foodItem,
            mealSlot: targetSlot
        )
        modelContext.insert(copy)
        try? modelContext.save()
        onCompleted()
        dismiss()
    }
}
