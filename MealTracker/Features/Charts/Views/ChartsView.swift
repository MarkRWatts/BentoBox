import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    let profile: UserProfile

    @Query(sort: \LoggedEntry.date) private var allLoggedEntries: [LoggedEntry]
    @State private var rangeDays = 30

    private var loggedEntries: [LoggedEntry] {
        allLoggedEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    private var summary: ChartsViewModel {
        ChartsViewModel(profile: profile, loggedEntries: loggedEntries, rangeDays: rangeDays)
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

                Section("Body") {
                    NavigationLink {
                        WeightView(profile: profile)
                    } label: {
                        WeightSummaryRowView(profile: profile)
                    }
                    NavigationLink {
                        BMIView(profile: profile)
                    } label: {
                        BMISummaryRowView(profile: profile)
                    }
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
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.orange.gradient, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading) {
                Text("\(streakDays) day\(streakDays == 1 ? "" : "s")")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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

private struct WeightSummaryRowView: View {
    let profile: UserProfile

    var body: some View {
        HStack {
            Text("Weight")
            Spacer()
            if let weightKG = profile.currentWeightKG {
                Text(profile.weightUnit.displayString(fromKG: weightKG))
                    .foregroundStyle(.secondary)
            } else {
                Text("Log your weight")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BMISummaryRowView: View {
    let profile: UserProfile

    private var bmi: Double? {
        guard let weightKG = profile.currentWeightKG else { return nil }
        return BMICalculator.bmi(weightKG: weightKG, heightCM: profile.heightCM)
    }

    var body: some View {
        HStack {
            Text("BMI")
            Spacer()
            if let bmi {
                let category = BMICalculator.category(for: bmi)
                Text(bmi, format: .number.precision(.fractionLength(1)))
                    .foregroundStyle(.secondary)
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)
            } else {
                Text("Log your weight")
                    .foregroundStyle(.secondary)
            }
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
                        .foregroundStyle(point.calories > target ? Color.brandProtein : Color.accentColor)
                        .cornerRadius(4)
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
