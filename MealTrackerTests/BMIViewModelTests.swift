import Testing
import Foundation
@testable import MealTracker

struct BMIViewModelTests {
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

    @Test func currentBMIUsesLatestWeightEntry() {
        let profile = makeProfile()
        let older = BodyMetricEntry(date: Date().addingTimeInterval(-86400 * 10), weightKG: 80, profile: profile)
        let latest = BodyMetricEntry(date: Date(), weightKG: 70, profile: profile)
        profile.weightHistory = [older, latest]

        let viewModel = BMIViewModel(profile: profile, weightEntries: profile.weightHistory, rangeDays: 30)

        #expect(abs((viewModel.currentBMI ?? 0) - BMICalculator.bmi(weightKG: 70, heightCM: 175)) < 0.001)
        #expect(viewModel.currentCategory == .normal)
    }

    @Test func currentBMIIsNilWithNoWeightHistory() {
        let profile = makeProfile()
        let viewModel = BMIViewModel(profile: profile, weightEntries: [], rangeDays: 30)

        #expect(viewModel.currentBMI == nil)
        #expect(viewModel.currentCategory == nil)
    }

    @Test func trendPointsExcludeEntriesOutsideRangeAndConvertWeightToBMI() {
        let profile = makeProfile()
        let referenceDate = Date()
        let withinRange = BodyMetricEntry(date: Calendar.current.date(byAdding: .day, value: -5, to: referenceDate)!, weightKG: 70, profile: profile)
        let outsideRange = BodyMetricEntry(date: Calendar.current.date(byAdding: .day, value: -40, to: referenceDate)!, weightKG: 80, profile: profile)

        let viewModel = BMIViewModel(profile: profile, weightEntries: [withinRange, outsideRange], rangeDays: 30, referenceDate: referenceDate)

        #expect(viewModel.trendPoints.count == 1)
        #expect(abs(viewModel.trendPoints[0].bmi - BMICalculator.bmi(weightKG: 70, heightCM: 175)) < 0.001)
    }
}
