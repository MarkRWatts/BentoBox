import Testing
import Foundation
@testable import MealTracker

struct WeeklyCardsViewModelTests {
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

    private func makeFoodItem(calories: Double, protein: Double, carbs: Double, fat: Double) -> FoodItem {
        FoodItem(name: "Test Food", servingSizeDescription: "1 serving", caloriesPerServing: calories, proteinGramsPerServing: protein, carbGramsPerServing: carbs, fatGramsPerServing: fat, source: .manual)
    }

    @Test func weekStartIsAlwaysAMonday() {
        let profile = makeProfile()
        // A known Wednesday, so this doesn't depend on the device locale's first weekday.
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 19
        let wednesday = Calendar.current.date(from: components)!

        let viewModel = WeeklyCardsViewModel(profile: profile, loggedEntries: [], referenceDate: wednesday)

        #expect(Calendar.current.component(.weekday, from: viewModel.weekStart) == 2)
        #expect(viewModel.weekStart <= wednesday)
    }

    @Test func weekOffsetPagesByWholeWeeks() {
        let profile = makeProfile()
        let referenceDate = Date()
        let thisWeek = WeeklyCardsViewModel(profile: profile, loggedEntries: [], weekOffset: 0, referenceDate: referenceDate)
        let nextWeek = WeeklyCardsViewModel(profile: profile, loggedEntries: [], weekOffset: 1, referenceDate: referenceDate)
        let lastWeek = WeeklyCardsViewModel(profile: profile, loggedEntries: [], weekOffset: -1, referenceDate: referenceDate)

        let daysForward = Calendar.current.dateComponents([.day], from: thisWeek.weekStart, to: nextWeek.weekStart).day
        let daysBack = Calendar.current.dateComponents([.day], from: lastWeek.weekStart, to: thisWeek.weekStart).day

        #expect(daysForward == 7)
        #expect(daysBack == 7)
    }

    @Test func weeklyCalorieBudgetDeltaSumsOnlyDaysThatOccurred() {
        let profile = makeProfile()
        let referenceDate = Date()
        let viewModel = WeeklyCardsViewModel(profile: profile, loggedEntries: [], referenceDate: referenceDate)
        // No calorie cycling configured, so every day of the week shares this same target.
        let target = viewModel.calorieTarget(on: viewModel.weekDates[0])

        let foodItem = makeFoodItem(calories: target - 200, protein: 0, carbs: 0, fat: 0)
        // Log against the first two days of the navigated week only.
        let entries = viewModel.weekDates.prefix(2).map {
            LoggedEntry(date: $0, quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: foodItem)
        }

        let loggedViewModel = WeeklyCardsViewModel(profile: profile, loggedEntries: entries, referenceDate: referenceDate)

        // Two days, each 200 under target, five days with nothing logged (excluded) = 400 net under.
        #expect(abs(loggedViewModel.weeklyCalorieBudgetDelta - 400) < 0.01)
    }

    @Test func averageMacroPercentsIsKcalPooledAcrossOccurredDays() {
        let profile = makeProfile()
        let referenceDate = Date()
        let base = WeeklyCardsViewModel(profile: profile, loggedEntries: [], referenceDate: referenceDate)

        // Day 1: all protein (100g -> 400 kcal). Day 2: all fat (100g -> 900 kcal).
        let proteinOnly = makeFoodItem(calories: 400, protein: 100, carbs: 0, fat: 0)
        let fatOnly = makeFoodItem(calories: 900, protein: 0, carbs: 0, fat: 100)
        let entries = [
            LoggedEntry(date: base.weekDates[0], quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: proteinOnly),
            LoggedEntry(date: base.weekDates[1], quantity: 1, mealSlotNameSnapshot: "Lunch", foodItem: fatOnly)
        ]

        let viewModel = WeeklyCardsViewModel(profile: profile, loggedEntries: entries, referenceDate: referenceDate)
        let percents = viewModel.averageMacroPercents

        // Pooled: 400 kcal protein / 1300 kcal total ≈ 30.8%, 900/1300 ≈ 69.2% fat, 0% carbs —
        // not a naive 50/50 average of each day's own 100%/100% split.
        #expect(abs(percents.protein - (400.0 / 1300.0 * 100)) < 0.01)
        #expect(abs(percents.fat - (900.0 / 1300.0 * 100)) < 0.01)
        #expect(percents.carbs == 0)
    }

    @Test func dailyPointsCarryPerDayCalorieCyclingTargets() {
        let profile = makeProfile()
        profile.isCalorieCyclingEnabled = true
        // Saturday (weekday 7) gets +300; the other 6 days absorb -50 each to balance the week.
        profile.calorieDayOverrides = [DayCalorieOverride(weekday: 7, extraCalories: 300, profile: profile)]

        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 19 // a Wednesday
        let wednesday = Calendar.current.date(from: components)!

        let viewModel = WeeklyCardsViewModel(profile: profile, loggedEntries: [], referenceDate: wednesday)
        let points = Dictionary(uniqueKeysWithValues: viewModel.dailyPoints.map { (Calendar.current.component(.weekday, from: $0.date), $0) })

        let saturdayTarget = points[7]!.calorieTarget
        let mondayTarget = points[2]!.calorieTarget

        // The bar strip's target line must actually move day to day when cycling is on — not
        // draw a flat line at one weekly figure.
        #expect(abs(saturdayTarget - (mondayTarget + 350)) < 0.01)
    }

    @Test func todayNumbersAreIndependentOfWeekOffset() {
        let profile = makeProfile()
        let referenceDate = Date()
        let foodItem = makeFoodItem(calories: 600, protein: 50, carbs: 40, fat: 20)
        let todayEntry = LoggedEntry(date: referenceDate, quantity: 1, mealSlotNameSnapshot: "Dinner", foodItem: foodItem)

        // Browsing a week far from today (e.g. two weeks back) must not change what the ring/pie
        // show for "today" — only the bar strip should reflect the navigated week.
        let browsingPastWeek = WeeklyCardsViewModel(profile: profile, loggedEntries: [todayEntry], weekOffset: -2, referenceDate: referenceDate)
        let browsingCurrentWeek = WeeklyCardsViewModel(profile: profile, loggedEntries: [todayEntry], weekOffset: 0, referenceDate: referenceDate)

        #expect(browsingPastWeek.todayConsumedCalories == 600)
        #expect(browsingPastWeek.todayConsumedCalories == browsingCurrentWeek.todayConsumedCalories)
    }
}
