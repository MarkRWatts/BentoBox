import Foundation

struct WeeklyInsights {
    let daysOverTarget: Int
    let daysUnderTarget: Int
    let daysOnTarget: Int
    let averageCalories: Double
    /// e.g. 92.3 meaning the week averaged 92.3% of the calorie target.
    let averagePercentOfTarget: Double
    /// Last weigh-in minus first weigh-in this week. Nil with fewer than two weigh-ins — not
    /// enough data to call it a trend.
    let weightChangeKG: Double?
}

/// Synthesizes the last 7 days (today inclusive, matching how "today" is always counted
/// elsewhere in this app, e.g. the logging streak) of already-computed trend points into a
/// small weekly summary. Takes points/entries rather than raw queries so it stays decoupled from
/// SwiftData and reuses whatever `ChartsViewModel`/`WeightView` already produced.
enum InsightsCalculator {
    static func weeklyInsights(
        calorieTrendPoints: [CalorieTrendPoint],
        target: Double,
        weightEntries: [BodyMetricEntry],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyInsights {
        let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: referenceDate)) ?? .distantPast

        let thisWeeksCalories = calorieTrendPoints.filter { $0.date >= weekStart }

        // A small tolerance around the target avoids classifying near-exact days as "over" or
        // "under" from rounding noise — exact equality is never meaningful here.
        let tolerance = target * 0.02
        var daysOver = 0
        var daysUnder = 0
        var daysOn = 0
        for point in thisWeeksCalories {
            if point.calories > target + tolerance {
                daysOver += 1
            } else if point.calories < target - tolerance {
                daysUnder += 1
            } else {
                daysOn += 1
            }
        }

        let averageCalories = thisWeeksCalories.isEmpty
            ? 0
            : thisWeeksCalories.reduce(0) { $0 + $1.calories } / Double(thisWeeksCalories.count)
        let averagePercentOfTarget = target > 0 ? (averageCalories / target) * 100 : 0

        let thisWeeksWeights = weightEntries.filter { $0.date >= weekStart }.sorted { $0.date < $1.date }
        let weightChangeKG: Double? = {
            guard thisWeeksWeights.count >= 2, let first = thisWeeksWeights.first, let last = thisWeeksWeights.last else {
                return nil
            }
            return last.weightKG - first.weightKG
        }()

        return WeeklyInsights(
            daysOverTarget: daysOver,
            daysUnderTarget: daysUnder,
            daysOnTarget: daysOn,
            averageCalories: averageCalories,
            averagePercentOfTarget: averagePercentOfTarget,
            weightChangeKG: weightChangeKG
        )
    }
}
