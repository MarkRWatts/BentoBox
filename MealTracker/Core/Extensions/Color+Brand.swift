import SwiftUI

/// A small food-illustration palette lifted from the app icon (clipboard green, salmon, avocado,
/// blueberry) so the in-app UI reads as the same product rather than defaulting to generic
/// iOS-blue-and-gray. Used for macro breakdowns, charts, and small accent moments — not meant to
/// replace `Color.accentColor`, which stays the primary interactive tint.
extension Color {
    /// Salmon — used for protein.
    static let brandProtein = Color(red: 0.882, green: 0.478, blue: 0.306)
    /// Avocado flesh — used for carbs.
    static let brandCarbs = Color(red: 0.639, green: 0.722, blue: 0.243)
    /// Blueberry — used for fat.
    static let brandFat = Color(red: 0.345, green: 0.361, blue: 0.596)
    /// Deeper forest green, for gradient endpoints alongside the lighter AccentColor.
    static let brandForest = Color(red: 0.220, green: 0.361, blue: 0.161)
}
