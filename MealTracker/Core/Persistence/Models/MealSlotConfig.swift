import Foundation
import SwiftData

@Model
final class MealSlotConfig {
    var id: UUID = UUID()
    var name: String = ""
    var slotType: MealSlotType = MealSlotType.meal
    var sortOrder: Int = 0
    var isEnabled: Bool = true
    var profile: UserProfile?

    // Nullify (not cascade): removing a meal slot must not destroy historical log entries.
    // LoggedEntry.mealSlotNameSnapshot preserves what the slot was called at log time.
    @Relationship(deleteRule: .nullify, inverse: \LoggedEntry.mealSlot)
    var entries: [LoggedEntry] = []

    init(name: String, slotType: MealSlotType, sortOrder: Int, isEnabled: Bool = true, profile: UserProfile? = nil) {
        self.id = UUID()
        self.name = name
        self.slotType = slotType
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.profile = profile
    }
}

extension MealSlotConfig {
    /// Default meal structure: Breakfast/Lunch/Dinner, each followed by a Snack slot.
    static func defaultSlots(for profile: UserProfile) -> [MealSlotConfig] {
        let definitions: [(name: String, type: MealSlotType)] = [
            ("Breakfast", .meal),
            ("Snack", .snack),
            ("Lunch", .meal),
            ("Snack", .snack),
            ("Dinner", .meal),
            ("Snack", .snack)
        ]
        return definitions.enumerated().map { index, definition in
            MealSlotConfig(name: definition.name, slotType: definition.type, sortOrder: index, profile: profile)
        }
    }
}
