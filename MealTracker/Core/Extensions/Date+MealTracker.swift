import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    }

    /// This date's day, combined with right-now's time-of-day. Used to default a new logged
    /// entry's timestamp to "now" while keeping it on the day actually being viewed — e.g.
    /// backfilling yesterday's breakfast this afternoon logs at yesterday 14:32, not midnight.
    var atCurrentTimeOfDay: Date {
        let now = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        return Calendar.current.date(
            bySettingHour: now.hour ?? 0,
            minute: now.minute ?? 0,
            second: now.second ?? 0,
            of: self
        ) ?? self
    }
}
