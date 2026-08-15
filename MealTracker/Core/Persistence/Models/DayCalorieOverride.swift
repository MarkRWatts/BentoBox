import Foundation
import SwiftData

@Model
final class DayCalorieOverride {
    var id: UUID = UUID()
    /// Calendar's `.weekday` convention: 1 = Sunday ... 7 = Saturday.
    var weekday: Int = 1
    /// Extra calories added on this day (negative allowed for a lighter day). The rest of the
    /// week automatically absorbs the opposite so the weekly total is unchanged — see
    /// `CalorieCyclingCalculator`.
    var extraCalories: Double = 0
    var profile: UserProfile?

    init(weekday: Int, extraCalories: Double, profile: UserProfile? = nil) {
        self.id = UUID()
        self.weekday = weekday
        self.extraCalories = extraCalories
        self.profile = profile
    }
}
