import Testing
import Foundation
@testable import MealTracker

struct MealSlotConfigTests {
    @Test func defaultSlotsMatchExpectedOrder() {
        let profile = UserProfile(
            sex: .male,
            birthDate: Date(),
            heightCM: 180,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
        let slots = MealSlotConfig.defaultSlots(for: profile)

        #expect(slots.count == 6)
        #expect(slots.map(\.name) == ["Breakfast", "Snack", "Lunch", "Snack", "Dinner", "Snack"])
        #expect(slots.map(\.sortOrder) == [0, 1, 2, 3, 4, 5])
        #expect(slots[0].slotType == .meal)
        #expect(slots[1].slotType == .snack)
    }
}
