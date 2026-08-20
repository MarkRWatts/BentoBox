import Foundation
import SwiftData

/// One drink, stored as a timestamp plus a volume — deliberately the same shape as
/// `BodyMetricEntry` rather than a running per-day counter, so a day's total is derived by
/// summing entries (see `WaterIntakeCalculator`) and an accidental extra glass can be undone by
/// deleting the last row instead of decrementing a total that has no history.
///
/// Volume is stored in millilitres regardless of the profile's `volumeUnit`, matching the
/// "canonical metric storage, unit preference is a UI-boundary concern" rule `UnitConversion`
/// already sets for kg and cm.
@Model
final class WaterLogEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var volumeML: Double = 0
    var profile: UserProfile?

    init(date: Date, volumeML: Double, profile: UserProfile? = nil) {
        self.id = UUID()
        self.date = date
        self.volumeML = volumeML
        self.profile = profile
    }
}
