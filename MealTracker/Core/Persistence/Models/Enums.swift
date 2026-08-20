import Foundation

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male
    case female

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive
    case extremelyActive

    var id: String { rawValue }

    /// Standard Mifflin-St Jeor activity multipliers.
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extremelyActive: return 1.9
        }
    }

    var displayName: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .lightlyActive: return "Lightly Active"
        case .moderatelyActive: return "Moderately Active"
        case .veryActive: return "Very Active"
        case .extremelyActive: return "Extremely Active"
        }
    }

    var descriptionText: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .lightlyActive: return "Light exercise 1-3 days/week"
        case .moderatelyActive: return "Moderate exercise 3-5 days/week"
        case .veryActive: return "Hard exercise 6-7 days/week"
        case .extremelyActive: return "Very hard exercise, physical job"
        }
    }
}

enum WeightGoal: String, Codable, CaseIterable, Identifiable {
    case lose
    case maintain
    case gain

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lose: return "Lose Weight"
        case .maintain: return "Maintain Weight"
        case .gain: return "Gain Weight"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds
    case stone

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kilograms: return "kg"
        case .pounds: return "lb"
        case .stone: return "st"
        }
    }

    /// Formats a canonical kg value for display in this unit.
    func displayString(fromKG kg: Double) -> String {
        switch self {
        case .kilograms:
            return String(format: "%.1f kg", kg)
        case .pounds:
            return String(format: "%.1f lb", UnitConversion.kgToPounds(kg))
        case .stone:
            let (stone, pounds) = UnitConversion.kgToStoneAndPounds(kg)
            return String(format: "%d st %.1f lb", stone, pounds)
        }
    }
}

enum HeightUnit: String, Codable, CaseIterable, Identifiable {
    case centimeters
    case feetInches

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .centimeters: return "cm"
        case .feetInches: return "ft/in"
        }
    }

    /// Formats a canonical cm value for display in this unit.
    func displayString(fromCM cm: Double) -> String {
        switch self {
        case .centimeters:
            return String(format: "%.0f cm", cm)
        case .feetInches:
            let (feet, inches) = UnitConversion.cmToFeetAndInches(cm)
            return "\(feet)' \(String(format: "%.1f", inches))\""
        }
    }
}

enum EntrySource: String, Codable {
    case manual
}

enum MealSlotType: String, Codable {
    case meal
    case snack
}

enum FoodSource: String, Codable {
    case openFoodFacts
    case labelScan
    case manual
    case usda
    case recipe
}
