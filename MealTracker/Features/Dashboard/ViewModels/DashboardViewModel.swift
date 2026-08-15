import Foundation

/// Stateless aggregation of a profile's daily targets against today's logged entries.
/// Recomputed fresh from the queried entries on every render — nothing here is persisted.
struct DashboardViewModel {
    let profile: UserProfile
    let todaysEntries: [LoggedEntry]
    /// Injectable for testability; defaults to today. 1 = Sunday ... 7 = Saturday.
    var weekday: Int = Calendar.current.component(.weekday, from: Date())

    var consumedCalories: Double {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    /// The target before calorie cycling is applied.
    private var baselineCalorieTarget: Double {
        TDEECalculator.dailyCalorieTarget(for: profile)
    }

    private var calorieDayOverridesByWeekday: [Int: Double] {
        Dictionary(uniqueKeysWithValues: profile.calorieDayOverrides.map { ($0.weekday, $0.extraCalories) })
    }

    var calorieTarget: Double {
        guard profile.isCalorieCyclingEnabled else { return baselineCalorieTarget }
        return CalorieCyclingCalculator.dailyCalorieTarget(
            baseline: baselineCalorieTarget,
            overrides: calorieDayOverridesByWeekday,
            for: weekday
        )
    }

    /// How much today's cycled target differs from the non-cycled baseline, for UI display. Nil
    /// when cycling is off or today happens to land exactly on baseline (nothing worth calling out).
    var calorieCyclingDeltaToday: Double? {
        guard profile.isCalorieCyclingEnabled, !profile.calorieDayOverrides.isEmpty else { return nil }
        let delta = calorieTarget - baselineCalorieTarget
        return abs(delta) < 0.5 ? nil : delta
    }

    var remainingCalories: Double {
        calorieTarget - consumedCalories
    }

    var macroTargets: MacroTargets {
        let weightKG = profile.currentWeightKG ?? 70
        let proteinPerKG = profile.proteinGramsPerKgOverride ?? 1.8
        return TDEECalculator.macroTargets(calorieTarget: calorieTarget, weightKG: weightKG, proteinGramsPerKG: proteinPerKG)
    }

    var consumedProtein: Double { todaysEntries.reduce(0) { $0 + $1.proteinGrams } }
    var consumedCarbs: Double { todaysEntries.reduce(0) { $0 + $1.carbGrams } }
    var consumedFat: Double { todaysEntries.reduce(0) { $0 + $1.fatGrams } }
}
