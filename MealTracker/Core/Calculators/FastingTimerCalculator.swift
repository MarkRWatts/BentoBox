import Foundation

/// Elapsed-time arithmetic for the fasting window — a start `Date` plus a goal length is the
/// whole model, so there's nothing to persist beyond `UserProfile.fastingStartedAt` and no timer
/// object to keep alive across launches. The card re-derives everything from the stored start on
/// each tick (see `FastingCardView`'s `TimelineView`), which is also why a fast survives the app
/// being killed mid-window.
enum FastingTimerCalculator {
    /// The protocols people actually name — 16:8 and 18:6 being the common ones, 24 for a full
    /// day. Offered as a picker rather than a free-entry field since the numbers are lore, not
    /// preference.
    static let goalPresetHours: [Double] = [12, 14, 16, 18, 20, 24]

    struct Progress {
        let elapsed: TimeInterval
        let goal: TimeInterval
        /// 0...1, clamped — a fast run past its goal shows a full bar, not an overflowing one.
        let fraction: Double
        /// Zero once the goal is met, never negative.
        let remaining: TimeInterval
        let hasReachedGoal: Bool
    }

    /// - Parameter now: injectable so tests (and each `TimelineView` tick) drive the clock
    ///   explicitly rather than reading `Date()` from inside.
    static func progress(startedAt: Date, goalHours: Double, now: Date = Date()) -> Progress {
        // A start in the future is reachable through the "edit start time" sheet if the device
        // clock moves; clamping keeps the bar and the label sane instead of counting backwards.
        let elapsed = max(now.timeIntervalSince(startedAt), 0)
        let goal = max(goalHours, 0) * 3600
        guard goal > 0 else {
            return Progress(elapsed: elapsed, goal: 0, fraction: 0, remaining: 0, hasReachedGoal: true)
        }
        return Progress(
            elapsed: elapsed,
            goal: goal,
            fraction: min(elapsed / goal, 1),
            remaining: max(goal - elapsed, 0),
            hasReachedGoal: elapsed >= goal
        )
    }

    /// "16h 04m", or "48m" under an hour — zero-padded minutes so the label doesn't jitter in
    /// width as it ticks.
    static func durationText(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(interval, 0) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : String(format: "%dm", minutes)
    }

    /// Same as `durationText` with seconds appended — used only for the live headline, where a
    /// visibly moving number is the point.
    static func preciseDurationText(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(interval, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return hours > 0
            ? String(format: "%dh %02dm %02ds", hours, minutes, seconds)
            : String(format: "%dm %02ds", minutes, seconds)
    }

    /// "16:8" — the fasting/eating split people name these by. Anything that doesn't leave an
    /// eating window (a 24h fast) is named by its length instead.
    static func goalLabel(hours: Double) -> String {
        let fasting = Int(hours.rounded())
        guard fasting > 0, fasting < 24 else { return "\(fasting)h" }
        return "\(fasting):\(24 - fasting)"
    }
}
