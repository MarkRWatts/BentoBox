import Foundation

/// Stateless aggregation of a profile's daily targets against today's logged entries.
/// Recomputed fresh from the queried entries on every render — nothing here is persisted.
struct DashboardViewModel {
    let profile: UserProfile
    let todaysEntries: [LoggedEntry]

    var consumedCalories: Double {
        todaysEntries.reduce(0) { $0 + $1.calories }
    }

    var calorieTarget: Double {
        TDEECalculator.dailyCalorieTarget(for: profile)
    }

    var remainingCalories: Double {
        calorieTarget - consumedCalories
    }

    var macroTargets: MacroTargets {
        TDEECalculator.macroTargets(for: profile)
    }

    var consumedProtein: Double { todaysEntries.reduce(0) { $0 + $1.proteinGrams } }
    var consumedCarbs: Double { todaysEntries.reduce(0) { $0 + $1.carbGrams } }
    var consumedFat: Double { todaysEntries.reduce(0) { $0 + $1.fatGrams } }
}
