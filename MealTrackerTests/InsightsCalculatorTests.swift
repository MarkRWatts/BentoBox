import Testing
import Foundation
@testable import MealTracker

struct InsightsCalculatorTests {
    private func daysAgo(_ n: Int, from referenceDate: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: referenceDate)!
    }

    @Test func classifiesDaysOverUnderAndOnTargetWithTolerance() {
        let referenceDate = Date()
        let points = [
            CalorieTrendPoint(date: daysAgo(0, from: referenceDate), calories: 2500), // over
            CalorieTrendPoint(date: daysAgo(1, from: referenceDate), calories: 1500), // under
            CalorieTrendPoint(date: daysAgo(2, from: referenceDate), calories: 2000), // exactly on
            CalorieTrendPoint(date: daysAgo(3, from: referenceDate), calories: 2010)  // within 2% tolerance -> on
        ]

        let insights = InsightsCalculator.weeklyInsights(
            calorieTrendPoints: points,
            target: 2000,
            weightEntries: [],
            referenceDate: referenceDate
        )

        #expect(insights.daysOverTarget == 1)
        #expect(insights.daysUnderTarget == 1)
        #expect(insights.daysOnTarget == 2)
    }

    @Test func excludesPointsOlderThanSevenDays() {
        let referenceDate = Date()
        let points = [
            CalorieTrendPoint(date: daysAgo(0, from: referenceDate), calories: 2000),
            CalorieTrendPoint(date: daysAgo(10, from: referenceDate), calories: 9999)
        ]

        let insights = InsightsCalculator.weeklyInsights(
            calorieTrendPoints: points,
            target: 2000,
            weightEntries: [],
            referenceDate: referenceDate
        )

        #expect(insights.daysOnTarget == 1)
        #expect(insights.averageCalories == 2000)
    }

    @Test func averagePercentOfTargetComputesCorrectly() {
        let referenceDate = Date()
        let points = [
            CalorieTrendPoint(date: daysAgo(0, from: referenceDate), calories: 1800),
            CalorieTrendPoint(date: daysAgo(1, from: referenceDate), calories: 2200)
        ]

        let insights = InsightsCalculator.weeklyInsights(
            calorieTrendPoints: points,
            target: 2000,
            weightEntries: [],
            referenceDate: referenceDate
        )

        #expect(abs(insights.averageCalories - 2000) < 0.001)
        #expect(abs(insights.averagePercentOfTarget - 100) < 0.001)
    }

    @Test func weightChangeIsNilWithFewerThanTwoEntries() {
        let referenceDate = Date()
        let entries = [BodyMetricEntry(date: referenceDate, weightKG: 70)]

        let insights = InsightsCalculator.weeklyInsights(
            calorieTrendPoints: [],
            target: 2000,
            weightEntries: entries,
            referenceDate: referenceDate
        )

        #expect(insights.weightChangeKG == nil)
    }

    @Test func weightChangeIsLastMinusFirstWithinTheWeek() {
        let referenceDate = Date()
        let entries = [
            BodyMetricEntry(date: daysAgo(6, from: referenceDate), weightKG: 71.5),
            BodyMetricEntry(date: daysAgo(3, from: referenceDate), weightKG: 71.0),
            BodyMetricEntry(date: daysAgo(0, from: referenceDate), weightKG: 70.2),
            // Outside the 7-day window — should not affect the result.
            BodyMetricEntry(date: daysAgo(20, from: referenceDate), weightKG: 90)
        ]

        let insights = InsightsCalculator.weeklyInsights(
            calorieTrendPoints: [],
            target: 2000,
            weightEntries: entries,
            referenceDate: referenceDate
        )

        #expect(abs((insights.weightChangeKG ?? 0) - (70.2 - 71.5)) < 0.001)
    }
}
