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
    /// "Snack · after Lunch" where several slots share a name — the default setup has three
    /// slots all called "Snack", which are indistinguishable in a menu or picker even though
    /// their order implies when they are. Unique names are returned exactly as configured.
    func disambiguatedName(among slots: [MealSlotConfig]) -> String {
        guard slots.filter({ $0.name == name }).count > 1,
              let index = slots.firstIndex(where: { $0.id == id }),
              let precedingMeal = slots[..<index].last(where: { $0.slotType == .meal })
        else { return name }
        return "\(name) · after \(precedingMeal.name)"
    }

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
