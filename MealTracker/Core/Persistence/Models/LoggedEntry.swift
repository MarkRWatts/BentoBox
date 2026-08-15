import Foundation
import SwiftData

@Model
final class LoggedEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Multiplier on the linked FoodItem's per-serving values (e.g. 1.5 servings).
    var quantity: Double = 1
    /// Denormalized so history still reads correctly if the meal slot is later renamed/deleted.
    var mealSlotNameSnapshot: String = ""
    /// HKObject UUID string, set once written to HealthKit, so edits update rather than duplicate.
    var healthKitSyncedObjectID: String?

    var foodItem: FoodItem?
    var mealSlot: MealSlotConfig?

    init(
        date: Date,
        quantity: Double,
        mealSlotNameSnapshot: String,
        foodItem: FoodItem? = nil,
        mealSlot: MealSlotConfig? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.quantity = quantity
        self.mealSlotNameSnapshot = mealSlotNameSnapshot
        self.foodItem = foodItem
        self.mealSlot = mealSlot
    }

    var calories: Double { (foodItem?.caloriesPerServing ?? 0) * quantity }
    var proteinGrams: Double { (foodItem?.proteinGramsPerServing ?? 0) * quantity }
    var carbGrams: Double { (foodItem?.carbGramsPerServing ?? 0) * quantity }
    var fatGrams: Double { (foodItem?.fatGramsPerServing ?? 0) * quantity }
}

extension LoggedEntry {
    /// Writes this entry's energy/macros to HealthKit and stores the resulting correlation UUID
    /// so a later edit or delete updates that same HealthKit sample instead of duplicating it.
    /// A no-op (silently) when HealthKit isn't authorized.
    @MainActor
    func syncToHealthKit(context: ModelContext) async {
        guard let foodItem else { return }
        guard let uuid = await HealthKitManager.shared.saveDietaryEntry(
            name: foodItem.name,
            calories: calories,
            proteinGrams: proteinGrams,
            carbGrams: carbGrams,
            fatGrams: fatGrams,
            date: date
        ) else { return }
        healthKitSyncedObjectID = uuid
        try? context.save()
    }

    @MainActor
    func removeFromHealthKit() async {
        guard let uuid = healthKitSyncedObjectID else { return }
        await HealthKitManager.shared.deleteDietaryEntry(uuid: uuid)
    }
}
