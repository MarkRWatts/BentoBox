import SwiftUI

/// Type system from the Claude Design calorie-tracker mockup: Archivo for headline numbers,
/// Manrope for everything else. Both are embedded as static weight instances extracted from
/// Google's variable font sources — see `MealTracker/Resources/Fonts` and `UIAppFonts` in
/// `project.yml`.
extension Font {
    static func archivo(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .custom(archivoPostScriptName(for: weight), size: size)
    }

    static func manrope(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(manropePostScriptName(for: weight), size: size)
    }

    private static func archivoPostScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: "ArchivoRoman-Medium"
        case .bold, .heavy, .black: "ArchivoRoman-Bold"
        default: "ArchivoRoman-SemiBold"
        }
    }

    private static func manropePostScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .medium: "Manrope-Medium"
        case .semibold: "Manrope-SemiBold"
        case .bold: "Manrope-Bold"
        case .heavy, .black: "Manrope-ExtraBold"
        default: "Manrope-Regular"
        }
    }
}
