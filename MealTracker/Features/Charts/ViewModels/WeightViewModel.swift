import Foundation

struct WeightTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weightKG: Double
}

/// Mirrors `BMIViewModel`'s shape — same pure, recompute-from-queried-entries approach, same
/// target derivation (midpoint of the normal BMI range, converted to a weight at this person's
/// height) so the BMI and Weight screens always agree on what "target" means.
struct WeightViewModel {
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

    var currentWeightKG: Double? {
        profile.currentWeightKG
    }

    var targetBMI: Double {
        BMICalculator.normalRangeMidpointBMI
    }

    var targetWeightKG: Double {
        BMICalculator.weight(forBMI: targetBMI, heightCM: profile.heightCM)
    }

    /// The weight-equivalent of the BMI gauge's 15...40 range at this person's height, so the
    /// weight gauge uses the same scale and color bands as the BMI gauge, just relabeled.
    var gaugeRangeKG: ClosedRange<Double> {
        let minWeight = BMICalculator.weight(forBMI: 15, heightCM: profile.heightCM)
        let maxWeight = BMICalculator.weight(forBMI: 40, heightCM: profile.heightCM)
        guard minWeight < maxWeight else { return 0...1 }
        return minWeight...maxWeight
    }

    var trendPoints: [WeightTrendPoint] {
        weightEntries
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
            .map { WeightTrendPoint(date: $0.date, weightKG: $0.weightKG) }
    }
}
