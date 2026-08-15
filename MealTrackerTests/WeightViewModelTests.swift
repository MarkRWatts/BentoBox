import Testing
import Foundation
@testable import MealTracker

struct WeightViewModelTests {
    private func makeProfile(heightCM: Double = 175) -> UserProfile {
        UserProfile(
            sex: .male,
            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: Date())!,
            heightCM: heightCM,
            activityLevel: .sedentary,
            goal: .maintain,
            goalRateKgPerWeek: 0
        )
    }

    @Test func currentWeightUsesLatestEntry() {
        let profile = makeProfile()
        let older = BodyMetricEntry(date: Date().addingTimeInterval(-86400 * 10), weightKG: 80, profile: profile)
        let latest = BodyMetricEntry(date: Date(), weightKG: 70, profile: profile)
        profile.weightHistory = [older, latest]

        let viewModel = WeightViewModel(profile: profile, weightEntries: profile.weightHistory, rangeDays: 30)

        #expect(viewModel.currentWeightKG == 70)
    }

    @Test func targetWeightMatchesBMICalculatorAtMidpoint() {
        let profile = makeProfile()
        let viewModel = WeightViewModel(profile: profile, weightEntries: [], rangeDays: 30)

        let expected = BMICalculator.weight(forBMI: BMICalculator.normalRangeMidpointBMI, heightCM: 175)
        #expect(abs(viewModel.targetWeightKG - expected) < 0.001)
    }

    @Test func gaugeRangeSpansBMI15To40AtThisHeight() {
        let profile = makeProfile()
        let viewModel = WeightViewModel(profile: profile, weightEntries: [], rangeDays: 30)

        let expectedMin = BMICalculator.weight(forBMI: 15, heightCM: 175)
        let expectedMax = BMICalculator.weight(forBMI: 40, heightCM: 175)
        #expect(abs(viewModel.gaugeRangeKG.lowerBound - expectedMin) < 0.001)
        #expect(abs(viewModel.gaugeRangeKG.upperBound - expectedMax) < 0.001)
    }

    @Test func trendPointsExcludeEntriesOutsideRange() {
        let profile = makeProfile()
        let referenceDate = Date()
        let withinRange = BodyMetricEntry(date: Calendar.current.date(byAdding: .day, value: -5, to: referenceDate)!, weightKG: 70, profile: profile)
        let outsideRange = BodyMetricEntry(date: Calendar.current.date(byAdding: .day, value: -40, to: referenceDate)!, weightKG: 80, profile: profile)

        let viewModel = WeightViewModel(profile: profile, weightEntries: [withinRange, outsideRange], rangeDays: 30, referenceDate: referenceDate)

        #expect(viewModel.trendPoints.count == 1)
        #expect(viewModel.trendPoints[0].weightKG == 70)
    }
}
