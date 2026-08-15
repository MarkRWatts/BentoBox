import Foundation

/// Pure kg/cm <-> display-unit conversions. The app's canonical stored unit is always metric
/// (kg, cm) — every calculator, HealthKit sample, and SwiftData field stays in metric so none of
/// that code needs to know about unit preference. This is purely a UI-boundary concern: format a
/// stored metric value for display, or parse a user-entered display value back into metric.
enum UnitConversion {
    private static let kgPerPound = 0.45359237
    private static let poundsPerStone = 14.0
    private static let cmPerInch = 2.54
    private static let inchesPerFoot = 12.0

    static func kgToPounds(_ kg: Double) -> Double { kg / kgPerPound }
    static func poundsToKg(_ lb: Double) -> Double { lb * kgPerPound }

    static func kgToStoneAndPounds(_ kg: Double) -> (stone: Int, pounds: Double) {
        let totalPounds = kgToPounds(kg)
        let stone = Int(totalPounds / poundsPerStone)
        let remainder = totalPounds - (Double(stone) * poundsPerStone)
        return (stone, remainder)
    }

    static func stoneAndPoundsToKg(stone: Int, pounds: Double) -> Double {
        poundsToKg((Double(stone) * poundsPerStone) + pounds)
    }

    static func cmToInches(_ cm: Double) -> Double { cm / cmPerInch }
    static func inchesToCm(_ inches: Double) -> Double { inches * cmPerInch }

    static func cmToFeetAndInches(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cmToInches(cm)
        let feet = Int(totalInches / inchesPerFoot)
        let remainder = totalInches - (Double(feet) * inchesPerFoot)
        return (feet, remainder)
    }

    static func feetAndInchesToCm(feet: Int, inches: Double) -> Double {
        inchesToCm((Double(feet) * inchesPerFoot) + inches)
    }
}
