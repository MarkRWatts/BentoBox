import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    let profile: UserProfile

    @Query(sort: \BodyMetricEntry.date) private var allWeightEntries: [BodyMetricEntry]
    @Query(sort: \LoggedEntry.date) private var allLoggedEntries: [LoggedEntry]
    @State private var rangeDays = 30

    private var weightEntries: [BodyMetricEntry] {
        allWeightEntries.filter { $0.profile?.id == profile.id }
    }

    private var loggedEntries: [LoggedEntry] {
        allLoggedEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    private var summary: ChartsViewModel {
        ChartsViewModel(profile: profile, weightEntries: weightEntries, loggedEntries: loggedEntries, rangeDays: rangeDays)
    }

    var body: some View {
        NavigationStack {
            List {
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
                    StreakCardView(streakDays: summary.currentStreakDays)
                }
                .listRowBackground(Color.clear)

                Section("Weight") {
                    WeightTrendChartView(points: summary.weightTrendPoints)
                }

                Section("Calories") {
                    CalorieTrendChartView(points: summary.calorieTrendPoints, target: summary.calorieTarget)
                }
            }
            .navigationTitle("Trends")
        }
    }
}

private struct StreakCardView: View {
    let streakDays: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("\(streakDays) day\(streakDays == 1 ? "" : "s")")
                    .font(.title2.bold())
                Text(streakDays > 0 ? "Logging streak" : "Log a meal to start a streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

private struct WeightTrendChartView: View {
    let points: [WeightTrendPoint]

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No Weight Logged", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log your weight to see a trend here."))
                .frame(height: 180)
        } else {
            Chart(points) { point in
                LineMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.weightKG))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", point.date, unit: .day), y: .value("Weight", point.weightKG))
            }
            .foregroundStyle(Color.accentColor)
            .frame(height: 180)
            .accessibilityLabel("Weight trend over time")
        }
    }
}

private struct CalorieTrendChartView: View {
    let points: [CalorieTrendPoint]
    let target: Double

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No Meals Logged", systemImage: "chart.bar.fill", description: Text("Log a meal to see your calorie trend here."))
                .frame(height: 180)
        } else {
            Chart {
                ForEach(points) { point in
                    BarMark(x: .value("Date", point.date, unit: .day), y: .value("Calories", point.calories))
                        .foregroundStyle(Color.accentColor)
                }
                RuleMark(y: .value("Target", target))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Target: \(Int(target))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(height: 180)
            .accessibilityLabel("Daily calories against target of \(Int(target))")
        }
    }
}
