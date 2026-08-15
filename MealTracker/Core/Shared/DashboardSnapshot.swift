import Foundation

/// The bridge between the main app and the widget extension. A widget process can't share the
/// app's live SwiftData `ModelContainer`, so the app writes this small snapshot to the shared
/// App Group container whenever Today's data changes, and the widget's TimelineProvider just
/// reads it back — no SwiftData, no HealthKit, nothing app-specific crosses the process boundary.
/// This file is compiled into both targets (see project.yml), so it stays Foundation-only.
struct DashboardSnapshot: Codable {
    var consumedCalories: Double
    var targetCalories: Double
    var consumedProtein: Double
    var targetProtein: Double
    var consumedCarbs: Double
    var targetCarbs: Double
    var consumedFat: Double
    var targetFat: Double
    var cyclingDeltaToday: Double?
    var updatedAt: Date

    static let appGroupID = "group.com.markwatts.MealTracker"
    private static let defaultsKey = "DashboardSnapshot"

    static let placeholder = DashboardSnapshot(
        consumedCalories: 1200,
        targetCalories: 2000,
        consumedProtein: 80,
        targetProtein: 126,
        consumedCarbs: 120,
        targetCarbs: 200,
        consumedFat: 40,
        targetFat: 55,
        cyclingDeltaToday: nil,
        updatedAt: Date()
    )

    static func load() -> DashboardSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
