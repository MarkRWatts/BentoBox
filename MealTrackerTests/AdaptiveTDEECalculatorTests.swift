import Testing
import Foundation
@testable import MealTracker

struct AdaptiveTDEECalculatorTests {
    private let referenceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 3, day: 1))!

    /// 14 consecutive days ending the day before `referenceDate`, each logging `calories`.
    private func dailyCalories(_ calories: Double, days: Int = 14) -> [Date: Double] {
        var result: [Date: Double] = [:]
        for offset in 1...days {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate)!.startOfDay
            result[day] = calories
        }
        return result
    }

    private func weighIns(startKG: Double, endKG: Double, daysAgoStart: Int = 14, daysAgoEnd: Int = 0) -> [(date: Date, weightKG: Double)] {
        [
            (date: Calendar.current.date(byAdding: .day, value: -daysAgoStart, to: referenceDate)!.startOfDay, weightKG: startKG),
            (date: Calendar.current.date(byAdding: .day, value: -daysAgoEnd, to: referenceDate)!.startOfDay, weightKG: endKG)
        ]
    }

    @Test func returnsNilWithFewerThanMinimumDaysOfCalorieData() {
        let result = AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(2000, days: 10),
            weightEntries: weighIns(startKG: 80, endKG: 80),
            referenceDate: referenceDate
        )
        #expect(result == nil)
    }

    @Test func returnsNilWithFewerThanTwoWeighIns() {
        let result = AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(2000),
            weightEntries: [(date: referenceDate, weightKG: 80)],
            referenceDate: referenceDate
        )
        #expect(result == nil)
    }

    @Test func estimatesHigherTDEEWhenLosingWeightAtGivenIntake() throws {
        // Lost 1kg over 14 days while eating 2000kcal/day — the deficit that explains that loss
        // implies a higher true TDEE than the intake alone would suggest.
        let result = try #require(AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(2000),
            weightEntries: weighIns(startKG: 81, endKG: 80),
            referenceDate: referenceDate
        ))
        // dailyDelta = (-1 * 7700) / 14 = -550; tdee = 2000 - (-550) = 2550
        #expect(abs(result.tdee - 2550) < 1)
        #expect(abs(result.averageDailyCalories - 2000) < 0.01)
        #expect(result.weightTrendKGPerWeek < 0)
    }

    @Test func estimatesTDEEEqualToIntakeWhenWeightSteady() throws {
        let result = try #require(AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(2200),
            weightEntries: weighIns(startKG: 75, endKG: 75),
            referenceDate: referenceDate
        ))
        #expect(abs(result.tdee - 2200) < 1)
        #expect(abs(result.weightTrendKGPerWeek) < 0.01)
    }

    @Test func estimatesLowerTDEEWhenGainingWeightAtGivenIntake() throws {
        let result = try #require(AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(2500),
            weightEntries: weighIns(startKG: 70, endKG: 71),
            referenceDate: referenceDate
        ))
        // dailyDelta = (1 * 7700) / 14 = 550; tdee = 2500 - 550 = 1950
        #expect(abs(result.tdee - 1950) < 1)
        #expect(result.weightTrendKGPerWeek > 0)
    }

    @Test func returnsNilForImplausibleResult() {
        // An extreme, almost certainly bad-data weight swing (15kg in 14 days at low intake)
        // should be rejected rather than handed back as a real TDEE.
        let result = AdaptiveTDEECalculator.estimate(
            dailyCalories: dailyCalories(500),
            weightEntries: weighIns(startKG: 95, endKG: 80),
            referenceDate: referenceDate
        )
        #expect(result == nil)
    }

    @Test func toleratesGapsByLookingFurtherBackForTheMostRecentLoggedDays() throws {
        // Only 14 of the last 20 days have a logged total; the other 6 (offsets 1,3,5,7,9,11)
        // are simply absent from the dictionary (never logged), not present with a 0 value. A
        // strict trailing-14-calendar-day window would only find 8 of these and return nil —
        // the wider lookback should still find the 14 most recent logged days, spanning all 20.
        var calories = dailyCalories(2000, days: 20)
        for offset in [1, 3, 5, 7, 9, 11] {
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: referenceDate)!.startOfDay
            calories.removeValue(forKey: day)
        }
        let result = try #require(AdaptiveTDEECalculator.estimate(
            dailyCalories: calories,
            weightEntries: weighIns(startKG: 80, endKG: 80, daysAgoStart: 20, daysAgoEnd: 0),
            referenceDate: referenceDate
        ))
        #expect(abs(result.averageDailyCalories - 2000) < 0.01)
        #expect(result.daysOfCalorieData == 14)
    }
}
