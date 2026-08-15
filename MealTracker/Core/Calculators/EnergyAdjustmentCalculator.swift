import Foundation

/// Adjusts the calorie target using today's *actual* HealthKit active-energy-burned instead of
/// the profile's fixed activity-level multiplier. This is the HealthKit-backed alternative to
/// `TDEECalculator`'s static estimate — factored out on its own so it can reuse the same
/// goal-delta math without entangling `TDEECalculator` (pure, no HealthKit dependency) with
/// HealthKit types.
enum EnergyAdjustmentCalculator {
    static func adjustedCalorieTarget(
        bmr: Double,
        activeEnergyBurnedToday: Double,
        goal: WeightGoal,
        goalRateKgPerWeek: Double
    ) -> Double {
        let maintenance = bmr + activeEnergyBurnedToday
        let dailyDelta = (goalRateKgPerWeek * 7700) / 7
        switch goal {
        case .lose: return maintenance - dailyDelta
        case .maintain: return maintenance
        case .gain: return maintenance + dailyDelta
        }
    }
}
