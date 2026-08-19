import SwiftUI
import UIKit

/// Literal palette from the Claude Design "full-width bars" (1a) calorie-tracker mockup. Kept
/// separate from `Color+Brand`'s app-wide palette because the mockup specifies exact hex values
/// with no dark variant — each token below pairs that light value with a hand-picked dark
/// counterpart (same hue, inverted lightness) so the redesigned Dashboard still works in dark
/// mode instead of just going literal-only in light mode.
extension Color {
    /// Page canvas behind the cards. Mockup: #eef7f1.
    static let dashboardCanvas = adaptive(light: 0xEEF7F1, dark: 0x0E1712)
    /// Card surfaces. Mockup: #ffffff.
    static let dashboardCard = adaptive(light: 0xFFFFFF, dark: 0x16211B)

    /// Headline ink (big numbers, names). Mockup: #10261d.
    static let dashboardInk = adaptive(light: 0x10261D, dark: 0xF1FBF5)
    /// Muted labels/subtitles. Mockup uses #7a968a, #8fa89b and #5c7a6c near-interchangeably —
    /// folded into one token here.
    static let dashboardInkSecondary = adaptive(light: 0x7A968A, dark: 0x93AFA0)
    /// Faintest text: unselected weekday letters. Mockup: #9cb8a9.
    static let dashboardInkFaint = adaptive(light: 0x9CB8A9, dark: 0x7C9686)

    /// Spring-green accent for values and status text. Mockup: #00a06c.
    static let dashboardAccent = adaptive(light: 0x00A06C, dark: 0x33C48D)
    /// Deeper emerald for the selected/"today" emphasis. Mockup: #006c4a.
    static let dashboardAccentDeep = adaptive(light: 0x006C4A, dark: 0x2AA873)
    /// Lime used for over-target bars and the fat macro fill. Mockup: #86cf3f.
    static let dashboardLime = adaptive(light: 0x86CF3F, dark: 0x9FE05A)
    /// Mint used for the carbs macro fill. Mockup: #2ed194.
    static let dashboardCarbFill = adaptive(light: 0x2ED194, dark: 0x4BE0A8)

    /// Empty progress-bar track. Mockup: #def0e5.
    static let dashboardBarTrack = adaptive(light: 0xDEF0E5, dark: 0x24352C)
    /// Default (not over-target) 7-day bar fill. Mockup: #a9dcc2.
    static let dashboardBarFill = adaptive(light: 0xA9DCC2, dark: 0x3E6B54)

    /// Hairline row/section dividers. Mockup: rgba(16,38,29,.07).
    static let dashboardDivider = adaptive(light: (0x10261D, 0.07), dark: (0xFFFFFF, 0.08))

    /// Text/numbers on top of a `dashboardAccentDeep` surface (e.g. the Trends "Verdict" card) —
    /// a fixed pale mint rather than an adaptive token, since it's sized to that one dark-green
    /// card background rather than to the system light/dark theme. Mockup: #c9e7d6.
    static let dashboardOnAccent = Color(red: 0.788, green: 0.906, blue: 0.839)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        adaptive(light: (light, 1), dark: (dark, 1))
    }

    private static func adaptive(light: (hex: UInt32, alpha: Double), dark: (hex: UInt32, alpha: Double)) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dashboardHex: dark.hex, alpha: dark.alpha)
                : UIColor(dashboardHex: light.hex, alpha: light.alpha)
        })
    }
}

private extension UIColor {
    convenience init(dashboardHex hex: UInt32, alpha: Double) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
