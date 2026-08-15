import Testing
import Foundation
@testable import MealTracker

struct ChartsViewModelTests {
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

    private func makeFoodItem(calories: Double) -> FoodItem {
        FoodItem(name: "Test Food", servingSizeDescription: "1 serving", caloriesPerServing: calories, proteinGramsPerServing: 0, carbGramsPerServing: 0, fatGramsPerServing: 0, source: .manual)
    }

    @Test func calorieTrendPointsGroupEntriesByDay() {
        let profile = makeProfile()
        let referenceDate = Date()
        let foodItem = makeFoodItem(calories: 200)
        let entry1 = LoggedEntry(date: referenceDate, quantity: 1, mealSlotNameSnapshot: "Breakfast", foodItem: foodItem)
        let entry2 = LoggedEntry(date: referenceDate.addingTimeInterval(3600), quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: foodItem)

        let viewModel = ChartsViewModel(profile: profile, loggedEntries: [entry1, entry2], rangeDays: 30, referenceDate: referenceDate)

        #expect(viewModel.calorieTrendPoints.count == 1)
        #expect(viewModel.calorieTrendPoints.first?.calories == 400)
    }

    @Test func currentStreakDaysCountsConsecutiveLoggedDaysFromToday() {
        let profile = makeProfile()
        let referenceDate = Date()
        let calendar = Calendar.current
        let foodItem = makeFoodItem(calories: 100)
        let entries = (0..<3).map { offset in
            LoggedEntry(date: calendar.date(byAdding: .day, value: -offset, to: referenceDate)!, quantity: 1, mealSlotNameSnapshot: "Snack", foodItem: foodItem)
        }

        let viewModel = ChartsViewModel(profile: profile, loggedEntries: entries, rangeDays: 30, referenceDate: referenceDate)

        #expect(viewModel.currentStreakDays == 3)
    }

    @Test func currentStreakDaysIsZeroWhenTodayHasNoEntry() {
        let profile = makeProfile()
        let referenceDate = Date()
        let calendar = Calendar.current
        let foodItem = makeFoodItem(calories: 100)
        let yesterdayEntry = LoggedEntry(date: calendar.date(byAdding: .day, value: -1, to: referenceDate)!, quantity: 1, mealSlotNameSnapshot: "Snack", foodItem: foodItem)

        let viewModel = ChartsViewModel(profile: profile, loggedEntries: [yesterdayEntry], rangeDays: 30, referenceDate: referenceDate)

        #expect(viewModel.currentStreakDays == 0)
    }
}
