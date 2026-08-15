import SwiftUI
import SwiftData
import Charts

struct WeightView: View {
    let profile: UserProfile

    @Query(sort: \BodyMetricEntry.date) private var allWeightEntries: [BodyMetricEntry]
    @State private var rangeDays = 90

    private var weightEntries: [BodyMetricEntry] {
        allWeightEntries.filter { $0.profile?.id == profile.id }
    }

    private var summary: WeightViewModel {
        WeightViewModel(profile: profile, weightEntries: weightEntries, rangeDays: rangeDays)
    }

    var body: some View {
        List {
            if let weightKG = summary.currentWeightKG {
                Section {
                    CurrentWeightCardView(
                        weightKG: weightKG,
                        targetWeightKG: summary.targetWeightKG,
                        targetBMI: summary.targetBMI,
                        gaugeRangeKG: summary.gaugeRangeKG,
                        unit: profile.weightUnit
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
                WeightTrendChartView(points: summary.trendPoints, targetWeightKG: summary.targetWeightKG, unit: profile.weightUnit)
            } footer: {
                Text("Target weight is set at the middle of the normal BMI range for your height, not a strict goal — talk to a healthcare provider before making significant changes.")
            }
        }
        .navigationTitle("Weight")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CurrentWeightCardView: View {
    let weightKG: Double
    let targetWeightKG: Double
    let targetBMI: Double
    let gaugeRangeKG: ClosedRange<Double>
    let unit: WeightUnit

    var body: some View {
        VStack(spacing: 12) {
            Text(unit.displayString(fromKG: weightKG))
                .font(.system(size: 40, weight: .bold, design: .rounded))

            Gauge(value: min(max(weightKG, gaugeRangeKG.lowerBound), gaugeRangeKG.upperBound), in: gaugeRangeKG) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            } minimumValueLabel: {
                Text(unit.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } maximumValueLabel: {
                Text(" ")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .gaugeStyle(.accessoryLinear)
            .tint(Gradient(colors: [.brandFat, .accentColor, .brandCarbs, .brandProtein]))
            .padding(.horizontal, 8)

            Text("Target: \(unit.displayString(fromKG: targetWeightKG)) (\(targetBMI, format: .number.precision(.fractionLength(1))) BMI)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct DisplayWeightPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

private struct WeightTrendChartView: View {
    let points: [WeightTrendPoint]
    let targetWeightKG: Double
    let unit: WeightUnit

    /// Converts stored kg values to the display unit before charting, so the axis itself reads
    /// in whatever unit the user picked rather than always plotting raw kilograms.
    private func displayValue(fromKG kg: Double) -> Double {
        switch unit {
        case .kilograms: return kg
        case .pounds: return UnitConversion.kgToPounds(kg)
        case .stone: return UnitConversion.kgToPounds(kg) / 14
        }
    }

    private var displayPoints: [DisplayWeightPoint] {
        points.map { DisplayWeightPoint(id: $0.id, date: $0.date, value: displayValue(fromKG: $0.weightKG)) }
    }

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No Weight Logged", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log your weight to see a trend here."))
                .frame(height: 180)
        } else {
            Chart {
                RuleMark(y: .value("Target", displayValue(fromKG: targetWeightKG)))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target: \(unit.displayString(fromKG: targetWeightKG))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                ForEach(displayPoints) { point in
                    AreaMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(.linearGradient(colors: [.accentColor.opacity(0.25), .accentColor.opacity(0)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.value))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.accentColor)
                    PointMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.value))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(height: 180)
            .accessibilityLabel("Weight trend over time")
        }
    }
}
