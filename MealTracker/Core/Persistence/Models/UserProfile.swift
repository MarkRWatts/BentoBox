import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var sex: BiologicalSex = BiologicalSex.female
    var birthDate: Date = Date()
    var heightCM: Double = 170
    var activityLevel: ActivityLevel = ActivityLevel.sedentary
    var goal: WeightGoal = WeightGoal.maintain
    var goalRateKgPerWeek: Double = 0
    var proteinGramsPerKgOverride: Double?
    var isCalorieCyclingEnabled: Bool = false
    /// Display/input unit preference only — every stored value (this field, calculator inputs)
    /// stays in metric regardless of this setting.
    var weightUnit: WeightUnit = WeightUnit.kilograms
    var heightUnit: HeightUnit = HeightUnit.centimeters
    /// ISO region code (e.g. "GB") to constrain Open Food Facts search results to. Nil means
    /// "automatic" — follow the device's region setting rather than a fixed choice.
    var foodSearchCountryCode: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \BodyMetricEntry.profile)
    var weightHistory: [BodyMetricEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \MealSlotConfig.profile)
    var mealSlots: [MealSlotConfig] = []

    @Relationship(deleteRule: .cascade, inverse: \DayCalorieOverride.profile)
    var calorieDayOverrides: [DayCalorieOverride] = []

    init(
        sex: BiologicalSex,
        birthDate: Date,
        heightCM: Double,
        activityLevel: ActivityLevel,
        goal: WeightGoal,
        goalRateKgPerWeek: Double,
        proteinGramsPerKgOverride: Double? = nil,
        weightUnit: WeightUnit = .kilograms,
        heightUnit: HeightUnit = .centimeters
    ) {
        self.id = UUID()
        self.sex = sex
        self.birthDate = birthDate
        self.heightCM = heightCM
        self.activityLevel = activityLevel
        self.goal = goal
        self.goalRateKgPerWeek = goalRateKgPerWeek
        self.proteinGramsPerKgOverride = proteinGramsPerKgOverride
        self.weightUnit = weightUnit
        self.heightUnit = heightUnit
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var ageYears: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }

    /// Derived from the most recent weight log entry rather than stored redundantly.
    var currentWeightKG: Double? {
        weightHistory.max(by: { $0.date < $1.date })?.weightKG
    }

    /// The English country name to send Open Food Facts as a `countries_tags_en` search filter —
    /// resolved from the explicit preference, falling back to the device's region when unset.
    /// Nil when neither resolves to a real region (e.g. a region-less locale), meaning "don't
    /// filter by country at all".
    var resolvedFoodSearchCountryName: String? {
        guard let code = foodSearchCountryCode ?? Locale.current.region?.identifier else { return nil }
        return Locale(identifier: "en_US").localizedString(forRegionCode: code)
    }
}
