import Testing
@testable import MealTracker

struct TDEECalculatorTests {
    @Test func bmrMaleKnownValue() {
        // 10*80 + 6.25*180 - 5*30 + 5 = 800 + 1125 - 150 + 5 = 1780
        let result = TDEECalculator.bmr(sex: .male, weightKG: 80, heightCM: 180, ageYears: 30)
        #expect(abs(result - 1780) < 0.001)
    }

    @Test func bmrFemaleKnownValue() {
        // 10*65 + 6.25*165 - 5*28 - 161 = 650 + 1031.25 - 140 - 161 = 1380.25
        let result = TDEECalculator.bmr(sex: .female, weightKG: 65, heightCM: 165, ageYears: 28)
        #expect(abs(result - 1380.25) < 0.001)
    }

    @Test func tdeeAppliesActivityMultiplier() {
        let result = TDEECalculator.tdee(bmr: 1500, activityLevel: .moderatelyActive)
        #expect(abs(result - 2325) < 0.001) // 1500 * 1.55
    }

    @Test func calorieTargetForLoseGoal() {
        // dailyDelta = 0.5*7700/7 = 550
        let target = TDEECalculator.dailyCalorieTarget(tdee: 2500, goal: .lose, goalRateKgPerWeek: 0.5)
        #expect(abs(target - 1950) < 0.001)
    }

    @Test func calorieTargetForGainGoal() {
        // dailyDelta = 0.25*7700/7 = 275
        let target = TDEECalculator.dailyCalorieTarget(tdee: 2500, goal: .gain, goalRateKgPerWeek: 0.25)
        #expect(abs(target - 2775) < 0.001)
    }

    @Test func calorieTargetForMaintainGoalIgnoresRate() {
        let target = TDEECalculator.dailyCalorieTarget(tdee: 2500, goal: .maintain, goalRateKgPerWeek: 0)
        #expect(abs(target - 2500) < 0.001)
    }

    @Test func macroTargetsSumApproximatelyToCalorieTarget() {
        let targets = TDEECalculator.macroTargets(calorieTarget: 2000, weightKG: 70, proteinGramsPerKG: 1.8)
        let totalKcal = (targets.proteinGrams * 4) + (targets.carbGrams * 4) + (targets.fatGrams * 9)
        #expect(abs(totalKcal - 2000) < 0.01)
        #expect(abs(targets.proteinGrams - 126) < 0.001) // 70 * 1.8
    }

    @Test func micronutrientTargetsVaryFiberBySexOnly() {
        let male = TDEECalculator.micronutrientTargets(calorieTarget: 2000, sex: .male)
        let female = TDEECalculator.micronutrientTargets(calorieTarget: 2000, sex: .female)
        #expect(male.fiberGrams == 38)
        #expect(female.fiberGrams == 25)
        #expect(male.sodiumMg == female.sodiumMg)
    }

    @Test func micronutrientTargetsScaleSaturatedFatAndSugarWithCalories() {
        let targets = TDEECalculator.micronutrientTargets(calorieTarget: 1800, sex: .male)
        #expect(abs(targets.saturatedFatGrams - 20) < 0.001) // 1800 * 0.10 / 9
        #expect(abs(targets.sugarGrams - 45) < 0.001) // 1800 * 0.10 / 4
        #expect(targets.sodiumMg == 2300)
    }
}
