import Foundation

/// Recalibrates TDEE from what actually happened — logged intake and real weight change — rather
/// than trusting the Mifflin-St Jeor formula's population-average estimate forever. Same idea
/// MacroFactor uses: if you ate 2,200kcal/day for two weeks and held weight steady, your true
/// TDEE is ~2,200; if you lost weight at that intake, it's higher.
///
/// Pure, stateless, and unit-testable in isolation — no persistence or SwiftData dependency (see
/// `TDEECalculator`'s own header for why that separation matters here too).
enum AdaptiveTDEECalculator {
    /// Below this many *logged* days, there's not enough signal to trust over the static formula
    /// — matches the ballpark MacroFactor itself needs before its own estimate stabilizes.
    static let minimumDays = 14
    /// How far back to search for those `minimumDays` logged days. Wider than `minimumDays`
    /// itself on purpose: a strict trailing-14-calendar-day window would mean a single missed log
    /// day permanently blocks the estimate until a perfect run accumulates again. Scanning back
    /// further tolerates the occasional gap the way a real user's logging actually looks.
    static let maxLookbackDays = 60

    struct Result {
        let tdee: Double
        let averageDailyCalories: Double
        /// Positive means gaining, negative losing.
        let weightTrendKGPerWeek: Double
        let daysOfCalorieData: Int
    }

    /// - Parameters:
    ///   - dailyCalories: Total logged calories per day, keyed by day (start-of-day `Date`).
    ///     Days absent from this dictionary are treated as "not logged", not "ate zero" — they're
    ///     excluded rather than counted as a 0-calorie day.
    ///   - weightEntries: Weight log entries in any order; at least 2 with distinct dates are
    ///     needed to fit a trend.
    ///   - referenceDate: Defaults to now; injectable for testing.
    /// - Returns: Nil when there isn't yet enough data (fewer than `minimumDays` logged days, or
    ///   fewer than 2 distinct weigh-in dates) or when the result would be implausible (a sign
    ///   that the input data is too noisy or sparse to trust yet).
    static func estimate(
        dailyCalories: [Date: Double],
        weightEntries: [(date: Date, weightKG: Double)],
        referenceDate: Date = Date()
    ) -> Result? {
        let calendar = Calendar.current
        let today = referenceDate.startOfDay
        let horizonStart = calendar.date(byAdding: .day, value: -maxLookbackDays, to: today) ?? today

        // Today is very likely still partial, so the search ends at yesterday. Most-recent-first
        // so the `minimumDays` kept are the latest logged days within the horizon, not an
        // arbitrary subset.
        let loggedDays = dailyCalories
            .filter { day, calories in day >= horizonStart && day < today && calories > 0 }
            .sorted { $0.key > $1.key }
            .prefix(minimumDays)
        guard loggedDays.count >= minimumDays, let earliestLoggedDay = loggedDays.map(\.key).min() else { return nil }
        let averageDailyCalories = loggedDays.reduce(0) { $0 + $1.value } / Double(loggedDays.count)

        // The real elapsed span the selected logged days cover — not just `minimumDays` — since
        // gaps mean those days can stretch further back than a gap-free run would.
        let elapsedDays = calendar.dateComponents([.day], from: earliestLoggedDay, to: today).day ?? minimumDays
        guard elapsedDays > 0 else { return nil }

        // Unlike calories, a same-day weigh-in is a complete reading (not a partial-day total),
        // so today is included here even though it's excluded from the calorie window above.
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let weightsInWindow = weightEntries.filter { $0.date >= earliestLoggedDay && $0.date < todayEnd }
        guard let slopePerDay = linearRegressionSlope(weightsInWindow, referenceDate: earliestLoggedDay) else { return nil }

        // The regression line's own fitted change over the window, not a raw first-minus-last —
        // smooths out day-to-day water-weight noise the same way a trend line on a scatter of
        // weigh-ins does visually.
        let weightChangeKG = slopePerDay * Double(elapsedDays)
        let dailyCalorieDelta = (weightChangeKG * 7700) / Double(elapsedDays)
        let tdee = averageDailyCalories - dailyCalorieDelta

        // A wildly implausible result (e.g. from a data-entry typo in a weigh-in) is more likely
        // bad input than a real metabolism — better to keep the static formula than hand back
        // nonsense.
        guard (800...6000).contains(tdee) else { return nil }

        return Result(
            tdee: tdee,
            averageDailyCalories: averageDailyCalories,
            weightTrendKGPerWeek: slopePerDay * 7,
            daysOfCalorieData: loggedDays.count
        )
    }

    /// Ordinary least-squares slope (kg/day) of weight against day-offset-from-`referenceDate`.
    /// Nil when there are fewer than 2 distinct dates to fit a line through.
    private static func linearRegressionSlope(
        _ entries: [(date: Date, weightKG: Double)],
        referenceDate: Date
    ) -> Double? {
        let calendar = Calendar.current
        let points = entries.map { entry -> (x: Double, y: Double) in
            let dayOffset = calendar.dateComponents([.day], from: referenceDate, to: entry.date).day ?? 0
            return (x: Double(dayOffset), y: entry.weightKG)
        }
        guard Set(points.map(\.x)).count >= 2 else { return nil }

        let n = Double(points.count)
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        let sumXY = points.reduce(0) { $0 + $1.x * $1.y }
        let sumX2 = points.reduce(0) { $0 + $1.x * $1.x }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return nil }
        return (n * sumXY - sumX * sumY) / denominator
    }
}
