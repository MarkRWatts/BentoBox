import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case basics, activity, goal, summary
    }

    var step: Step = .basics

    var sex: BiologicalSex = .female
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    var heightCM: Double = 170
    var currentWeightKG: Double = 70
    var weightUnit: WeightUnit = .kilograms
    var heightUnit: HeightUnit = .centimeters
    var activityLevel: ActivityLevel = .sedentary
    var goal: WeightGoal = .maintain
    var goalRateKgPerWeek: Double = 0.5
    var useHealthKitEnergyAdjustment: Bool = false
    var isImportingFromHealthKit: Bool = false
    var didImportFromHealthKit: Bool = false

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    var effectiveGoalRate: Double {
        goal == .maintain ? 0 : goalRateKgPerWeek
    }

    var previewBMR: Double {
        TDEECalculator.bmr(sex: sex, weightKG: currentWeightKG, heightCM: heightCM, ageYears: ageYears)
    }

    var previewTDEE: Double {
        TDEECalculator.tdee(bmr: previewBMR, activityLevel: activityLevel)
    }

    var previewCalorieTarget: Double {
        TDEECalculator.dailyCalorieTarget(tdee: previewTDEE, goal: goal, goalRateKgPerWeek: effectiveGoalRate)
    }

    var previewMacros: MacroTargets {
        TDEECalculator.macroTargets(calorieTarget: previewCalorieTarget, weightKG: currentWeightKG)
    }

    /// Prefills Basics-step fields from HealthKit where available, leaving anything HealthKit
    /// doesn't have (or the user hasn't granted) untouched so manual entry still works as a
    /// fallback for every field.
    func importFromHealthKit() async {
        isImportingFromHealthKit = true
        defer { isImportingFromHealthKit = false }

        guard await HealthKitManager.shared.requestAuthorization() else { return }
        let data = await HealthKitManager.shared.fetchStartingProfileData()

        if let sex = data.sex { self.sex = sex }
        if let birthDate = data.birthDate { self.birthDate = birthDate }
        if let heightCM = data.heightCM { self.heightCM = heightCM }
        if let weightKG = data.weightKG { self.currentWeightKG = weightKG }
        didImportFromHealthKit = true
    }

    func goNext() {
        guard let nextStep = Step(rawValue: step.rawValue + 1) else { return }
        step = nextStep
    }

    func goBack() {
        guard let previousStep = Step(rawValue: step.rawValue - 1) else { return }
        step = previousStep
    }

    func completeOnboarding(context: ModelContext) async {
        let profile = UserProfile(
            sex: sex,
            birthDate: birthDate,
            heightCM: heightCM,
            activityLevel: activityLevel,
            goal: goal,
            goalRateKgPerWeek: effectiveGoalRate,
            useHealthKitEnergyAdjustment: useHealthKitEnergyAdjustment,
            weightUnit: weightUnit,
            heightUnit: heightUnit
        )
        context.insert(profile)

        if useHealthKitEnergyAdjustment {
            await HealthKitManager.shared.requestAuthorization()
        }

        let initialWeightEntry = BodyMetricEntry(date: Date(), weightKG: currentWeightKG, source: .manual, profile: profile)
        context.insert(initialWeightEntry)

        for slot in MealSlotConfig.defaultSlots(for: profile) {
            context.insert(slot)
        }

        try? context.save()

        if useHealthKitEnergyAdjustment {
            await HealthKitManager.shared.saveBodyMass(kg: currentWeightKG, date: Date())
        }
    }
}
