import Testing
@testable import MealTracker

struct CalorieCyclingCalculatorTests {
    @Test func returnsBaselineForEveryDayWhenNoOverrides() {
        for weekday in 1...7 {
            let result = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: [:], for: weekday)
            #expect(result == 2000)
        }
    }

    @Test func overrideDayGetsBaselinePlusExtra() {
        // Friday = 6, Saturday = 7
        let overrides = [6: 300.0, 7: 300.0]
        let friday = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: 6)
        let saturday = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: 7)
        #expect(friday == 2300)
        #expect(saturday == 2300)
    }

    @Test func nonOverrideDaysSplitCompensationEvenly() {
        // Total extra = 600 across 2 override days, spread across the remaining 5 days = -120 each.
        let overrides = [6: 300.0, 7: 300.0]
        for weekday in [1, 2, 3, 4, 5] {
            let result = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: weekday)
            #expect(abs(result - 1880) < 0.001)
        }
    }

    @Test func weeklyTotalAlwaysMatchesUncycledBaseline() {
        let overrides = [6: 300.0, 7: 500.0]
        let total = CalorieCyclingCalculator.weeklyTotal(baseline: 2000, overrides: overrides)
        #expect(abs(total - 2000 * 7) < 0.001)
    }

    @Test func weeklyTotalHoldsWithSingleOverrideDay() {
        let overrides = [6: 700.0]
        let total = CalorieCyclingCalculator.weeklyTotal(baseline: 1800, overrides: overrides)
        #expect(abs(total - 1800 * 7) < 0.001)
    }

    @Test func allSevenDaysOverriddenHonorsEachDaysExplicitValueWithoutCrashing() {
        // Every weekday has an explicit override, so there's no day left to auto-balance —
        // each day should just get its own explicit value rather than dividing by zero.
        let overrides = Dictionary(uniqueKeysWithValues: (1...7).map { ($0, 500.0) })
        for weekday in 1...7 {
            let result = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: weekday)
            #expect(result == 2500)
        }
    }

    @Test func negativeOverrideIsTreatedAsALighterDay() {
        // A -400 "light day" on Monday means the other 6 days each gain +400/6.
        let overrides = [2: -400.0]
        let monday = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: 2)
        let tuesday = CalorieCyclingCalculator.dailyCalorieTarget(baseline: 2000, overrides: overrides, for: 3)
        #expect(monday == 1600)
        #expect(abs(tuesday - (2000 + 400.0 / 6)) < 0.001)
    }
}
