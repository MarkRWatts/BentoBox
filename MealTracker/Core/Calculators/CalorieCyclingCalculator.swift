import Foundation

/// Spreads user-chosen "high calorie days" (e.g. Friday and Saturday) against the rest of the
/// week so the weekly total — and therefore weekly macros, since macros are derived from that
/// day's calorie target — always nets out to exactly what it would've been without cycling.
/// Days not explicitly overridden absorb the opposite of the overridden days' total, split
/// evenly, rather than the user having to hand-balance the week themselves.
enum CalorieCyclingCalculator {
    /// - Parameters:
    ///   - baseline: The non-cycled daily calorie target.
    ///   - overrides: Explicit extra-calorie deltas keyed by weekday (1 = Sunday ... 7 =
    ///     Saturday, matching `Calendar`'s `.weekday` component). Omit a weekday to let it
    ///     auto-balance.
    ///   - weekday: Which day to compute the target for.
    static func dailyCalorieTarget(baseline: Double, overrides: [Int: Double], for weekday: Int) -> Double {
        guard !overrides.isEmpty else { return baseline }

        if let extra = overrides[weekday] {
            return baseline + extra
        }

        let nonOverrideDayCount = 7 - overrides.count
        // All seven days overridden — there's no day left to absorb compensation, so just use
        // the baseline unmodified rather than dividing by zero.
        guard nonOverrideDayCount > 0 else { return baseline }

        let totalExtra = overrides.values.reduce(0, +)
        let compensationPerDay = totalExtra / Double(nonOverrideDayCount)
        return baseline - compensationPerDay
    }

    /// Sum of all seven days' targets — always equal to `baseline * 7` by construction, exposed
    /// mainly so the UI can show the user the balance holds rather than asserting it blindly.
    static func weeklyTotal(baseline: Double, overrides: [Int: Double]) -> Double {
        (1...7).reduce(0) { total, weekday in
            total + dailyCalorieTarget(baseline: baseline, overrides: overrides, for: weekday)
        }
    }
}
