import Foundation

struct MacroTargets {
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
}

/// Fixed/formula-based targets rather than personalized ones — good enough for a first pass,
/// unlike the macro targets above these aren't tuned per-person beyond scaling with calories.
struct MicronutrientTargets {
    let fiberGrams: Double
    let saturatedFatGrams: Double
    let sugarGrams: Double
    let sodiumMg: Double
}

/// Pure, stateless TDEE/calorie-target math. No persistence or UIKit dependency, unit-testable
/// in isolation. Only profile *inputs* are ever persisted — these outputs are always recomputed
/// on demand so the formula can change later without a data migration.
enum TDEECalculator {
    /// Mifflin-St Jeor equation.
    static func bmr(sex: BiologicalSex, weightKG: Double, heightCM: Double, ageYears: Int) -> Double {
        let base = (10 * weightKG) + (6.25 * heightCM) - (5 * Double(ageYears))
        switch sex {
        case .male: return base + 5
        case .female: return base - 161
        }
    }

    static func tdee(bmr: Double, activityLevel: ActivityLevel) -> Double {
        bmr * activityLevel.multiplier
    }

    /// 1 kg of fat ≈ 7700 kcal, so the daily surplus/deficit needed for a weekly rate is
    /// (rate * 7700) / 7.
    static func dailyCalorieTarget(tdee: Double, goal: WeightGoal, goalRateKgPerWeek: Double) -> Double {
        let dailyDelta = (goalRateKgPerWeek * 7700) / 7
        switch goal {
        case .lose: return tdee - dailyDelta
        case .maintain: return tdee
        case .gain: return tdee + dailyDelta
        }
    }

    static func macroTargets(calorieTarget: Double, weightKG: Double, proteinGramsPerKG: Double = 1.8) -> MacroTargets {
        let proteinGrams = weightKG * proteinGramsPerKG
        let proteinKcal = proteinGrams * 4
        let fatKcal = calorieTarget * 0.25
        let fatGrams = fatKcal / 9
        let remainingKcal = max(calorieTarget - proteinKcal - fatKcal, 0)
        let carbGrams = remainingKcal / 4
        return MacroTargets(proteinGrams: proteinGrams, carbGrams: carbGrams, fatGrams: fatGrams)
    }

    static func dailyCalorieTarget(for profile: UserProfile) -> Double {
        let weightKG = profile.currentWeightKG ?? 70
        let bmrValue = bmr(sex: profile.sex, weightKG: weightKG, heightCM: profile.heightCM, ageYears: profile.ageYears)
        let tdeeValue = tdee(bmr: bmrValue, activityLevel: profile.activityLevel)
        return dailyCalorieTarget(tdee: tdeeValue, goal: profile.goal, goalRateKgPerWeek: profile.goalRateKgPerWeek)
    }

    static func macroTargets(for profile: UserProfile) -> MacroTargets {
        let weightKG = profile.currentWeightKG ?? 70
        let calorieTarget = dailyCalorieTarget(for: profile)
        let proteinPerKG = profile.proteinGramsPerKgOverride ?? 1.8
        return macroTargets(calorieTarget: calorieTarget, weightKG: weightKG, proteinGramsPerKG: proteinPerKG)
    }

    /// Fiber uses the standard US dietary guideline adult values (male/female); saturated fat and
    /// sugar are capped at 10% of calorie target each (a common general guideline for both, kept
    /// as a ceiling rather than tuned per-person); sodium is the flat adult upper limit regardless
    /// of calorie target.
    static func micronutrientTargets(calorieTarget: Double, sex: BiologicalSex) -> MicronutrientTargets {
        MicronutrientTargets(
            fiberGrams: sex == .male ? 38 : 25,
            saturatedFatGrams: (calorieTarget * 0.10) / 9,
            sugarGrams: (calorieTarget * 0.10) / 4,
            sodiumMg: 2300
        )
    }

    static func micronutrientTargets(for profile: UserProfile) -> MicronutrientTargets {
        micronutrientTargets(calorieTarget: dailyCalorieTarget(for: profile), sex: profile.sex)
    }
}
