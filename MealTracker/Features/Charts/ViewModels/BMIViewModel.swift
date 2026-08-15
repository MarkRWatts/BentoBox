import Foundation

struct BMITrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let bmi: Double
}

/// Mirrors `ChartsViewModel`'s shape: pure aggregation of weight history into BMI over time,
/// recomputed fresh from queried entries rather than persisted. Height is treated as constant
/// (the profile only tracks one current height), which is the standard simplifying assumption
/// for adult BMI tracking.
struct BMIViewModel {
    let profile: UserProfile
    let weightEntries: [BodyMetricEntry]
    let rangeDays: Int
    private let calendar = Calendar.current
    private let referenceDate: Date

    init(profile: UserProfile, weightEntries: [BodyMetricEntry], rangeDays: Int, referenceDate: Date = Date()) {
        self.profile = profile
        self.weightEntries = weightEntries
        self.rangeDays = rangeDays
        self.referenceDate = referenceDate
    }

    private var cutoffDate: Date {
        calendar.date(byAdding: .day, value: -rangeDays, to: calendar.startOfDay(for: referenceDate)) ?? .distantPast
    }

    var currentBMI: Double? {
        guard let weightKG = profile.currentWeightKG else { return nil }
        return BMICalculator.bmi(weightKG: weightKG, heightCM: profile.heightCM)
    }

    var currentCategory: BMICategory? {
        currentBMI.map(BMICalculator.category(for:))
    }

    /// Midpoint of the normal range — aiming at the center rather than either edge.
    var targetBMI: Double {
        BMICalculator.normalRangeMidpointBMI
    }

    var targetWeightKG: Double {
        BMICalculator.weight(forBMI: targetBMI, heightCM: profile.heightCM)
    }

    var trendPoints: [BMITrendPoint] {
        weightEntries
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
            .map { BMITrendPoint(date: $0.date, bmi: BMICalculator.bmi(weightKG: $0.weightKG, heightCM: profile.heightCM)) }
    }
}
