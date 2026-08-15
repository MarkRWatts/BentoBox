import Foundation

enum BMICategory: String {
    case underweight
    case normal
    case overweight
    case obese

    var displayName: String {
        switch self {
        case .underweight: return "Underweight"
        case .normal: return "Normal"
        case .overweight: return "Overweight"
        case .obese: return "Obese"
        }
    }
}

/// Standard WHO body mass index formula and category thresholds. Pure, stateless, no
/// persistence/UIKit dependency — same shape as `TDEECalculator`.
enum BMICalculator {
    static func bmi(weightKG: Double, heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        let heightM = heightCM / 100
        return weightKG / (heightM * heightM)
    }

    static func category(for bmi: Double) -> BMICategory {
        switch bmi {
        case ..<18.5: return .underweight
        case 18.5..<25: return .normal
        case 25..<30: return .overweight
        default: return .obese
        }
    }

    /// Midpoint of the normal BMI range (18.5–25) — used as the default target for both the BMI
    /// and weight screens rather than either edge, since aiming at a boundary leaves no margin.
    static let normalRangeMidpointBMI = 21.75

    /// Inverse of `bmi(weightKG:heightCM:)` — the weight at which a given height yields a given
    /// BMI. Used both for a target weight display and, with the category thresholds, to scale a
    /// weight gauge in the same terms as the BMI gauge.
    static func weight(forBMI bmi: Double, heightCM: Double) -> Double {
        guard heightCM > 0 else { return 0 }
        let heightM = heightCM / 100
        return bmi * heightM * heightM
    }
}
