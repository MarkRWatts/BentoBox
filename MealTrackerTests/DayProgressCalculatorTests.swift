import Testing
import Foundation
@testable import MealTracker

struct DayProgressCalculatorTests {
    private func makeProfile() -> UserProfile {
        UserProfile(
            sex: .male,
            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: Date())!,
            heightCM: 180,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
    }

    private func makeFoodItem(calories: Double, protein: Double) -> FoodItem {
        FoodItem(name: "Test Food", servingSizeDescription: "1 serving", caloriesPerServing: calories, proteinGramsPerServing: protein, carbGramsPerServing: 0, fatGramsPerServing: 0, source: .manual)
    }

    @Test func hasEntriesFalseForDayWithNothingLogged() {
        let profile = makeProfile()
        let progress = DayProgressCalculator.dayProgress(for: Date(), profile: profile, entries: [])

        #expect(progress.hasEntries == false)
    }

    @Test func hasEntriesFalseForFutureDayEvenWithOtherDaysLogged() {
        let profile = makeProfile()
        let today = Date()
        let futureDay = Calendar.current.date(byAdding: .day, value: 5, to: today)!
        let foodItem = makeFoodItem(calories: 500, protein: 30)
        let entry = LoggedEntry(date: today, quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: foodItem)

        let progress = DayProgressCalculator.dayProgress(for: futureDay, profile: profile, entries: [entry])

        #expect(progress.hasEntries == false)
    }

    @Test func computesCalorieAndProteinFractionsFromThatDaysEntries() {
        let profile = makeProfile()
        let day = Date()
        let foodItem = makeFoodItem(calories: 500, protein: 40)
        let entry1 = LoggedEntry(date: day, quantity: 1, mealSlotNameSnapshot: "Breakfast", foodItem: foodItem)
        let entry2 = LoggedEntry(date: day.addingTimeInterval(3600), quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: foodItem)
        // A different day's entry must not leak into this day's totals.
        let otherDayEntry = LoggedEntry(date: day.addingTimeInterval(-86400 * 2), quantity: 1, mealSlotNameSnapshot: "Snack", foodItem: foodItem)

        let progress = DayProgressCalculator.dayProgress(for: day, profile: profile, entries: [entry1, entry2, otherDayEntry])

        #expect(progress.hasEntries == true)
        #expect(progress.caloriesConsumed == 1000)
        #expect(progress.proteinConsumed == 80)
    }

    @Test func caloriesTargetRespectsCalorieCyclingForTheGivenWeekday() {
        let profile = makeProfile()
        profile.isCalorieCyclingEnabled = true
        // Saturday (weekday 7) gets +300; other days auto-balance to absorb the difference.
        profile.calorieDayOverrides = [DayCalorieOverride(weekday: 7, extraCalories: 300, profile: profile)]

        let calendar = Calendar.current
        var saturdayComponents = DateComponents()
        saturdayComponents.year = 2026
        saturdayComponents.month = 8
        saturdayComponents.day = 15 // a Saturday
        let saturday = calendar.date(from: saturdayComponents)!

        var mondayComponents = DateComponents()
        mondayComponents.year = 2026
        mondayComponents.month = 8
        mondayComponents.day = 17 // a Monday
        let monday = calendar.date(from: mondayComponents)!

        let saturdayProgress = DayProgressCalculator.dayProgress(for: saturday, profile: profile, entries: [])
        let mondayProgress = DayProgressCalculator.dayProgress(for: monday, profile: profile, entries: [])

        // Saturday gets baseline + 300; the other 6 days absorb -300/6 = -50 each so the
        // week's total is unchanged — so Saturday should read exactly 350 higher than Monday.
        #expect(abs(saturdayProgress.caloriesTarget - (mondayProgress.caloriesTarget + 350)) < 0.01)
    }
}
