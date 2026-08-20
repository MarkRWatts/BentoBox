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
    /// Opt-in — when on, `adaptiveCalorieTarget` (once populated) replaces the static
    /// Mifflin-St Jeor estimate as the baseline calorie target. See `AdaptiveTDEECalculator`.
    var isAdaptiveCalorieTargetEnabled: Bool = false
    /// Cached weekly, not recomputed on every read, so the target stays stable day to day rather
    /// than jittering with each new log entry. Nil until at least
    /// `AdaptiveTDEECalculator.minimumDays` of logged intake and 2+ weigh-ins exist.
    var adaptiveCalorieTarget: Double?
    var adaptiveCalorieTargetUpdatedAt: Date?
    /// Display/input unit preference only — every stored value (this field, calculator inputs)
    /// stays in metric regardless of this setting.
    var weightUnit: WeightUnit = WeightUnit.kilograms
    var heightUnit: HeightUnit = HeightUnit.centimeters
    /// Water tracking is on by default — a hydration card is a normal thing for a tracker to
    /// show — while the fasting timer is off until asked for, since fasting is a deliberate
    /// practice rather than something everyone logging food is doing.
    var isWaterTrackingEnabled: Bool = true
    var dailyWaterTargetML: Double = 2000
    /// One "glass" — what a single tap of the card's add button logs.
    var waterServingML: Double = 250
    /// Display/input preference only; every stored volume stays in ml. Same rule as
    /// `weightUnit`/`heightUnit` above — but stored as a raw string rather than as the enum
    /// itself, because SwiftData's lightweight migration doesn't backfill a *new* non-optional
    /// enum column on a store that predates it: the property reads back nil and traps on the
    /// cast the moment the profile is loaded. A `String` column with a default survives that,
    /// which `weightUnit`/`heightUnit` never had to (both existed in the original schema).
    var volumeUnitRawValue: String = VolumeUnit.milliliters.rawValue
    var isFastingTimerEnabled: Bool = false
    /// Hours of the fasting window — the "16" in 16:8. See `FastingTimerCalculator`.
    var fastingGoalHours: Double = 16
    /// Non-nil only while a fast is actually running. Storing just the start (rather than a
    /// ticking counter) is what lets a fast survive relaunch — everything else is derived.
    var fastingStartedAt: Date?
    /// The previous completed fast, kept as a single start/end pair so the card can show "last
    /// fast 16h 12m" without carrying a whole session history table for a feature this small.
    var lastFastStartedAt: Date?
    var lastFastEndedAt: Date?
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

    @Relationship(deleteRule: .cascade, inverse: \Recipe.profile)
    var recipes: [Recipe] = []

    @Relationship(deleteRule: .cascade, inverse: \WaterLogEntry.profile)
    var waterLog: [WaterLogEntry] = []

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

    var volumeUnit: VolumeUnit {
        get { VolumeUnit(rawValue: volumeUnitRawValue) ?? .milliliters }
        set { volumeUnitRawValue = newValue.rawValue }
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
