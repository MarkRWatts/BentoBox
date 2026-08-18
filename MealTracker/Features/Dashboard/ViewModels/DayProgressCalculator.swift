import Foundation

/// A single day's progress against its calorie/protein targets, for rendering a small ring
/// glyph in the week strip or month calendar.
struct DayProgress: Identifiable {
    let id: Date
    let date: Date
    let caloriesConsumed: Double
    let caloriesTarget: Double
    let proteinConsumed: Double
    let proteinTarget: Double
    /// False for future days and past days with nothing logged — the glyph renders as a bare
    /// track (no arc) in both cases rather than a misleading 0%-filled ring.
    let hasEntries: Bool
}

/// Reuses `DashboardViewModel` per day rather than re-deriving TDEE/calorie-cycling math, so the
/// glyph automatically respects calorie cycling for any weekday, past or future.
enum DayProgressCalculator {
    static func dayProgress(for date: Date, profile: UserProfile, entries: [LoggedEntry]) -> DayProgress {
        let dayEntries = entries.filter { $0.date >= date.startOfDay && $0.date < date.endOfDay }
        let weekday = Calendar.current.component(.weekday, from: date)
        let summary = DashboardViewModel(profile: profile, todaysEntries: dayEntries, weekday: weekday)
        return DayProgress(
            id: date.startOfDay,
            date: date,
            caloriesConsumed: summary.consumedCalories,
            caloriesTarget: summary.calorieTarget,
            proteinConsumed: summary.consumedProtein,
            proteinTarget: summary.macroTargets.proteinGrams,
            hasEntries: !dayEntries.isEmpty
        )
    }
}
