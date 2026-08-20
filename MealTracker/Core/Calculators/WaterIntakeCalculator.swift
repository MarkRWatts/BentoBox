import Foundation

/// A day's water total and how it compares to the profile's target. Pure and stateless — it
/// takes already-fetched entries rather than a `ModelContext`, the same separation
/// `DayProgressCalculator` keeps, so the arithmetic is testable without SwiftData.
enum WaterIntakeCalculator {
    /// Sums only the entries falling on `day` — callers pass whatever they already have queried
    /// (`DashboardView` hands over the whole profile's log), so the day filter lives here rather
    /// than being assumed of the input.
    static func totalML(entries: [WaterLogEntry], on day: Date, calendar: Calendar = .current) -> Double {
        entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .reduce(0) { $0 + $1.volumeML }
    }

    /// 0...1, clamped — over-drinking fills the bar rather than overflowing it, matching how
    /// `MacroBreakdownView` and `MicronutrientBreakdownView` already cap their own bars.
    static func progress(consumedML: Double, targetML: Double) -> Double {
        guard targetML > 0 else { return 0 }
        return min(max(consumedML / targetML, 0), 1)
    }

    /// How many whole glasses of `servingML` the day's total covers — drives the row of filled
    /// drop glyphs on the card. Rounded down, and nudged by a hair first so a total built up from
    /// exactly N glasses can't land on N-1 through floating-point drift.
    static func glassesCompleted(consumedML: Double, servingML: Double) -> Int {
        guard servingML > 0, consumedML > 0 else { return 0 }
        return Int((consumedML / servingML) + 0.0001)
    }

    /// How many glass glyphs to draw: enough to cover the target, capped so an unusually large
    /// target (or tiny glass) can't spill a 30-glyph row across the card.
    static func glassesInTarget(targetML: Double, servingML: Double, maximum: Int = 10) -> Int {
        guard targetML > 0, servingML > 0 else { return 0 }
        return min(Int((targetML / servingML).rounded(.up)), maximum)
    }
}
