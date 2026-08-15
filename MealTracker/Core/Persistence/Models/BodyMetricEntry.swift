import Foundation
import SwiftData

@Model
final class BodyMetricEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKG: Double = 0
    var source: EntrySource = EntrySource.manual
    var profile: UserProfile?

    init(date: Date, weightKG: Double, source: EntrySource = .manual, profile: UserProfile? = nil) {
        self.id = UUID()
        self.date = date
        self.weightKG = weightKG
        self.source = source
        self.profile = profile
    }
}
