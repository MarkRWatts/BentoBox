import Foundation

struct DailyMacroPoint: Identifiable {
    let id: Date
    let date: Date
    let calories: Double
    /// This day's own calorie target — not a flat weekly value, since calorie cycling can give
    /// different weekdays different targets.
    let calorieTarget: Double
    let proteinGrams: Double
    let carbGrams: Double
    let fatGrams: Double
    /// False for future days and past days with nothing logged.
    let hasEntries: Bool
}

/// Fixed Mon–Sun calendar week, deliberately separate from `ChartsViewModel`'s trailing-N-day
/// `rangeDays` semantics (which already feed the independently-tested `InsightsCalculator`) —
/// conflating the two "week" definitions into one type would confuse both. Pure struct, no
/// SwiftData/Charts dependency, recomputed fresh from queried entries on every render, matching
/// `DashboardViewModel`/`ChartsViewModel`.
struct WeeklyCardsViewModel {
    let profile: UserProfile
    let loggedEntries: [LoggedEntry]
    /// 0 = the week containing `referenceDate`, negative/positive page back/forward.
    let weekOffset: Int
    private let referenceDate: Date

    /// Monday-first, hardcoded — matches the Mon–Sun layout used throughout this feature rather
    /// than the device locale's first weekday.
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    init(profile: UserProfile, loggedEntries: [LoggedEntry], weekOffset: Int = 0, referenceDate: Date = Date()) {
        self.profile = profile
        self.loggedEntries = loggedEntries
        self.weekOffset = weekOffset
        self.referenceDate = referenceDate
    }

    private func startOfWeek(for date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date.startOfDay
    }

    var weekStart: Date {
        let thisWeekStart = startOfWeek(for: referenceDate)
        return calendar.date(byAdding: .day, value: weekOffset * 7, to: thisWeekStart) ?? thisWeekStart
    }

    var weekDates: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private var baselineCalorieTarget: Double { TDEECalculator.dailyCalorieTarget(for: profile) }

    private var calorieDayOverridesByWeekday: [Int: Double] {
        guard profile.isCalorieCyclingEnabled else { return [:] }
        return Dictionary(uniqueKeysWithValues: profile.calorieDayOverrides.map { ($0.weekday, $0.extraCalories) })
    }

    /// This day's calorie target, respecting calorie cycling — mirrors how
    /// `DashboardViewModel`/`DayProgressCalculator` compute a per-weekday target, so the weekly
    /// cards never disagree with what Today shows for the same day.
    func calorieTarget(on day: Date) -> Double {
        CalorieCyclingCalculator.dailyCalorieTarget(
            baseline: baselineCalorieTarget,
            overrides: calorieDayOverridesByWeekday,
            for: calendar.component(.weekday, from: day)
        )
    }

    var macroTargets: MacroTargets { TDEECalculator.macroTargets(for: profile) }

    private func point(for day: Date) -> DailyMacroPoint {
        let dayEntries = loggedEntries.filter { $0.date >= day.startOfDay && $0.date < day.endOfDay }
        return DailyMacroPoint(
            id: day.startOfDay,
            date: day,
            calories: dayEntries.reduce(0) { $0 + $1.calories },
            calorieTarget: calorieTarget(on: day),
            proteinGrams: dayEntries.reduce(0) { $0 + $1.proteinGrams },
            carbGrams: dayEntries.reduce(0) { $0 + $1.carbGrams },
            fatGrams: dayEntries.reduce(0) { $0 + $1.fatGrams },
            hasEntries: !dayEntries.isEmpty
        )
    }

    /// One point per day of the navigated week — drives the bar strips on both cards.
    var dailyPoints: [DailyMacroPoint] { weekDates.map(point) }

    /// Sum over days that occurred of (that day's target - consumed); positive = net under
    /// budget for the week. Uses each day's own cycled target, not a flat weekly figure.
    var weeklyCalorieBudgetDelta: Double {
        dailyPoints.filter { $0.hasEntries }.reduce(0) { $0 + ($1.calorieTarget - $1.calories) }
    }

    /// Pooled (kcal-weighted) week average, not an average of daily percentages — more robust
    /// when days have very different totals. Drives the "AVG" row under the macro bars.
    var averageMacroPercents: (protein: Double, carbs: Double, fat: Double) {
        let occurred = dailyPoints.filter { $0.hasEntries }
        return macroPercents(
            proteinGrams: occurred.reduce(0) { $0 + $1.proteinGrams },
            carbGrams: occurred.reduce(0) { $0 + $1.carbGrams },
            fatGrams: occurred.reduce(0) { $0 + $1.fatGrams }
        )
    }

    /// Today's actual numbers, independent of `weekOffset` — the ring/pie on the left of each
    /// card always reflects today's progress, while the bars/footer/AVG on the right reflect
    /// whichever week is currently being browsed.
    private var todayPoint: DailyMacroPoint { point(for: referenceDate) }

    var todayConsumedCalories: Double { todayPoint.calories }
    var todayCalorieTarget: Double { todayPoint.calorieTarget }

    var todayMacroPercents: (protein: Double, carbs: Double, fat: Double) {
        macroPercents(proteinGrams: todayPoint.proteinGrams, carbGrams: todayPoint.carbGrams, fatGrams: todayPoint.fatGrams)
    }

    private func macroPercents(proteinGrams: Double, carbGrams: Double, fatGrams: Double) -> (protein: Double, carbs: Double, fat: Double) {
        let proteinKcal = proteinGrams * 4
        let carbKcal = carbGrams * 4
        let fatKcal = fatGrams * 9
        let total = proteinKcal + carbKcal + fatKcal
        guard total > 0 else { return (0, 0, 0) }
        return (proteinKcal / total * 100, carbKcal / total * 100, fatKcal / total * 100)
    }
}
