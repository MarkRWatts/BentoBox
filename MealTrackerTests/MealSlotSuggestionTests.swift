import Testing
import Foundation
@testable import MealTracker

struct MealSlotSuggestionTests {
    private func defaultSlots() -> [MealSlotConfig] {
        let profile = UserProfile(
            sex: .male,
            birthDate: Date(),
            heightCM: 180,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
        return MealSlotConfig.defaultSlots(for: profile)
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    @Test func morningSuggestsTheFirstMeal() {
        let slot = MealSlotSuggestion.suggestedSlot(at: date(hour: 8), from: defaultSlots())

        #expect(slot?.name == "Breakfast")
    }

    @Test func middaySuggestsLunch() {
        let slot = MealSlotSuggestion.suggestedSlot(at: date(hour: 13), from: defaultSlots())

        #expect(slot?.name == "Lunch")
    }

    @Test func eveningSuggestsDinner() {
        let slot = MealSlotSuggestion.suggestedSlot(at: date(hour: 19), from: defaultSlots())

        #expect(slot?.name == "Dinner")
    }

    /// Late night and the small hours both belong to the last meal of the day — wrapping back
    /// around to breakfast at 1am would be worse than useless.
    @Test func lateNightSuggestsTheLastMealRatherThanWrappingToBreakfast() {
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 23), from: defaultSlots())?.name == "Dinner")
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 2), from: defaultSlots())?.name == "Dinner")
    }

    @Test func snackSlotsAreNeverSuggested() {
        let slots = defaultSlots()
        let suggestions = stride(from: 0, through: 23, by: 1).map {
            MealSlotSuggestion.suggestedSlot(at: date(hour: $0), from: slots)
        }

        #expect(suggestions.allSatisfy { $0?.slotType == .meal })
    }

    @Test func disabledSlotsAreSkipped() {
        let slots = defaultSlots()
        slots.first(where: { $0.name == "Lunch" })?.isEnabled = false

        // With Breakfast and Dinner left, the day splits in half at 14:00 rather than in thirds.
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 13), from: slots)?.name == "Breakfast")
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 15), from: slots)?.name == "Dinner")
    }

    /// A custom setup of four meals splits into four windows, not the default three.
    @Test func windowsFollowHowManyMealSlotsAreConfigured() {
        let profile = UserProfile(
            sex: .male,
            birthDate: Date(),
            heightCM: 180,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
        let slots = ["Breakfast", "Brunch", "Lunch", "Dinner"].enumerated().map {
            MealSlotConfig(name: $0.element, slotType: .meal, sortOrder: $0.offset, profile: profile)
        }

        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 7), from: slots)?.name == "Breakfast")
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 11), from: slots)?.name == "Brunch")
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 15), from: slots)?.name == "Lunch")
        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 20), from: slots)?.name == "Dinner")
    }

    @Test func profileWithOnlySnackSlotsStillGetsATarget() {
        let profile = UserProfile(
            sex: .male,
            birthDate: Date(),
            heightCM: 180,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
        let slots = [MealSlotConfig(name: "Snack", slotType: .snack, sortOrder: 0, profile: profile)]

        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 13), from: slots)?.name == "Snack")
    }

    @Test func noEnabledSlotsSuggestsNothing() {
        let slots = defaultSlots()
        slots.forEach { $0.isEnabled = false }

        #expect(MealSlotSuggestion.suggestedSlot(at: date(hour: 13), from: slots) == nil)
    }
}
