import SwiftUI
import UIKit

/// Literal palette from the Claude Design "full-width bars" (1a) calorie-tracker mockup. Kept
/// separate from `Color+Brand`'s app-wide palette because the mockup specifies exact hex values
/// with no dark variant — each token below pairs that light value with a hand-picked dark
/// counterpart (same hue, inverted lightness) so the redesigned Dashboard still works in dark
/// mode instead of just going literal-only in light mode.
extension Color {
    /// Page canvas behind the cards. The mockup specifies a tinted mint (#eef7f1), but the
    /// `Form`-based screens (Settings and every editor pushed from it) can't be tinted without
    /// fighting UIKit, so the mint only ever applied to half the app and read as two different
    /// designs bolted together. Taken straight from `systemGroupedBackground` instead — the exact
    /// color those screens already use — so the whole app shares one canvas in both appearances
    /// (#f2f2f7 light, black dark, which is what this token already resolved to in dark mode).
    static let dashboardCanvas = Color(uiColor: .systemGroupedBackground)
    /// Card surfaces. Mockup: #ffffff. Dark uses Apple's standard `secondarySystemBackground`
    /// gray (#1c1c1e) instead of a tinted dark green, to match `dashboardCanvas` — the same
    /// white-card-on-grouped-grey pairing the `Form` screens get for free.
    static let dashboardCard = adaptive(light: 0xFFFFFF, dark: 0x1C1C1E)

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

    /// Water's own accent — the one place the Dashboard deliberately steps outside the mockup's
    /// green palette, since a green drop reads as anything but water. Picked teal-leaning rather
    /// than a pure blue so it still sits next to `dashboardAccent` without clashing.
    static let dashboardWater = adaptive(light: 0x0A93C9, dark: 0x45BDEA)
    /// The pale end of the water ramp — see `dashboardWaterFill(_:of:)`.
    static let dashboardWaterPale = adaptive(light: 0xA9D6EC, dark: 0x2E5D75)

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

    /// Fill for one glass in `WaterCardView`'s row: a ramp from `dashboardWaterPale` at the first
    /// glass to the full `dashboardWater` blue at the last, so a filling row reads as deepening
    /// rather than as N identical drops. Interpolated inside a `UIColor` trait closure
    /// (rather than between two already-resolved colors) so both ends of the ramp stay correct
    /// when the theme flips.
    static func dashboardWaterFill(_ index: Int, of count: Int) -> Color {
        let fraction = count > 1 ? min(max(Double(index) / Double(count - 1), 0), 1) : 1
        return Color(uiColor: UIColor { traits in
            let start = UIColor(dashboardWaterPale).resolvedColor(with: traits)
            let end = UIColor(dashboardWater).resolvedColor(with: traits)
            var startComponents = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
            var endComponents = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
            start.getRed(&startComponents.red, green: &startComponents.green, blue: &startComponents.blue, alpha: &startComponents.alpha)
            end.getRed(&endComponents.red, green: &endComponents.green, blue: &endComponents.blue, alpha: &endComponents.alpha)
            let mix = { (from: CGFloat, to: CGFloat) in from + (to - from) * CGFloat(fraction) }
            return UIColor(
                red: mix(startComponents.red, endComponents.red),
                green: mix(startComponents.green, endComponents.green),
                blue: mix(startComponents.blue, endComponents.blue),
                alpha: mix(startComponents.alpha, endComponents.alpha)
            )
        })
    }

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
