import Foundation

struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKG: Double
}

struct CalorieTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
}

/// Pure aggregation of a profile's weight/calorie history into chart-ready points, plus a
/// same-day-inclusive logging streak. No persistence or Charts dependency, unit-testable in
/// isolation — mirrors DashboardViewModel's "recompute fresh from queried entries" approach.
struct ChartsViewModel {
    let profile: UserProfile
    let weightEntries: [BodyMetricEntry]
    let loggedEntries: [LoggedEntry]
    let rangeDays: Int
    private let calendar = Calendar.current
    private let referenceDate: Date

    init(profile: UserProfile, weightEntries: [BodyMetricEntry], loggedEntries: [LoggedEntry], rangeDays: Int, referenceDate: Date = Date()) {
        self.profile = profile
        self.weightEntries = weightEntries
        self.loggedEntries = loggedEntries
        self.rangeDays = rangeDays
        self.referenceDate = referenceDate
    }

    private var cutoffDate: Date {
        calendar.date(byAdding: .day, value: -rangeDays, to: calendar.startOfDay(for: referenceDate)) ?? .distantPast
    }

    var calorieTarget: Double {
        TDEECalculator.dailyCalorieTarget(for: profile)
    }

    var weightTrendPoints: [WeightTrendPoint] {
        weightEntries
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
            .map { WeightTrendPoint(date: $0.date, weightKG: $0.weightKG) }
    }

    var calorieTrendPoints: [CalorieTrendPoint] {
        let grouped = Dictionary(grouping: loggedEntries.filter { $0.date >= cutoffDate }) { calendar.startOfDay(for: $0.date) }
        return grouped
            .map { date, entries in CalorieTrendPoint(date: date, calories: entries.reduce(0) { $0 + $1.calories }) }
            .sorted { $0.date < $1.date }
    }

    /// Consecutive days, counting back from today, with at least one logged entry. Computed on
    /// the fly rather than persisted so it can never drift out of sync with the actual log.
    var currentStreakDays: Int {
        let loggedDays = Set(loggedEntries.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: referenceDate)
        while loggedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
