import SwiftUI
import SwiftData
import Charts

extension BMICategory {
    /// UI-only concern kept out of the pure calculator — reuses the app's existing brand
    /// palette rather than introducing a separate ad hoc color set, while still reading with the
    /// conventional cool-to-warm "healthier to more caution" association for a health metric.
    var color: Color {
        switch self {
        case .underweight: return .brandFat
        case .normal: return .accentColor
        case .overweight: return .brandCarbs
        case .obese: return .brandProtein
        }
    }
}

struct BMIView: View {
    let profile: UserProfile

    @Query(sort: \BodyMetricEntry.date) private var allWeightEntries: [BodyMetricEntry]
    @State private var rangeDays = 90

    private var weightEntries: [BodyMetricEntry] {
        allWeightEntries.filter { $0.profile?.id == profile.id }
    }

    private var summary: BMIViewModel {
        BMIViewModel(profile: profile, weightEntries: weightEntries, rangeDays: rangeDays)
    }

    var body: some View {
        List {
            if let bmi = summary.currentBMI, let category = summary.currentCategory {
                Section {
                    CurrentBMICardView(
                        bmi: bmi,
                        category: category,
                        targetBMI: summary.targetBMI,
                        targetWeightKG: summary.targetWeightKG,
                        weightUnit: profile.weightUnit
                    )
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Picker("Range", selection: $rangeDays) {
                    Text("7 Days").tag(7)
                    Text("30 Days").tag(30)
                    Text("90 Days").tag(90)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                BMITrendChartView(points: summary.trendPoints, targetBMI: summary.targetBMI)
            } footer: {
                Text("BMI is a general screening measure based on height and weight — it doesn't account for muscle mass, bone density, or body composition, so use it as one signal among others rather than a standalone verdict.")
            }
        }
        .navigationTitle("BMI")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CurrentBMICardView: View {
    let bmi: Double
    let category: BMICategory
    let targetBMI: Double
    let targetWeightKG: Double
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 12) {
            Text(bmi, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(category.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(category.color.gradient, in: Capsule())

            Gauge(value: min(max(bmi, 15), 40), in: 15...40) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text("15")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text("40")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Gradient(colors: [.brandFat, .accentColor, .brandCarbs, .brandProtein]))
            .padding(.horizontal, 8)

            Text("Target: \(targetBMI, format: .number.precision(.fractionLength(1))) BMI (\(weightUnit.displayString(fromKG: targetWeightKG)))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct BMITrendChartView: View {
    let points: [BMITrendPoint]
    let targetBMI: Double

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No Weight Logged", systemImage: "figure.arms.open", description: Text("Log your weight to see your BMI trend here."))
                .frame(height: 180)
        } else {
            Chart {
                RectangleMark(yStart: .value("Normal Low", 18.5), yEnd: .value("Normal High", 25))
                    .foregroundStyle(Color.accentColor.opacity(0.12))

                RuleMark(y: .value("Target", targetBMI))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target: \(targetBMI, format: .number.precision(.fractionLength(1)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                ForEach(points) { point in
                    AreaMark(x: .value("Date", point.date, unit: .day), y: .value("BMI", point.bmi))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.25), .accentColor.opacity(0)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", point.date, unit: .day), y: .value("BMI", point.bmi))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                    PointMark(x: .value("Date", point.date, unit: .day), y: .value("BMI", point.bmi))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(height: 180)
            .accessibilityLabel("BMI trend over time")
        }
    }
}
