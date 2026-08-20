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
    /// The days that have at least one entry, keyed by start-of-day. The week strip and month
    /// calendar only need "does this day get a dot", and each was answering that by walking
    /// every logged entry once per day drawn — a full pass per cell, 30-odd of them to render a
    /// month. Built once by the screen that owns the entries and passed down instead.
    static func daysWithEntries(_ entries: [LoggedEntry]) -> Set<Date> {
        Set(entries.map { $0.date.startOfDay })
    }

    /// Entries bucketed by start-of-day, so a screen drawing several days at once groups the log
    /// once rather than filtering all of it per day.
    static func entriesByDay(_ entries: [LoggedEntry]) -> [Date: [LoggedEntry]] {
        Dictionary(grouping: entries, by: { $0.date.startOfDay })
    }

    /// Start-of-day keys for the days (within `entriesByDay`) whose calories ended up over
    /// target. Only ever checks days that already have entries — a day with nothing logged can
    /// never be "over" — so this stays cheap regardless of how far back a screen scrolls.
    static func daysOverTarget(from entriesByDay: [Date: [LoggedEntry]], profile: UserProfile) -> Set<Date> {
        Set(entriesByDay.compactMap { day, dayEntries in
            let progress = dayProgress(for: day, profile: profile, entries: dayEntries)
            return progress.caloriesConsumed > progress.caloriesTarget ? day : nil
        })
    }

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
