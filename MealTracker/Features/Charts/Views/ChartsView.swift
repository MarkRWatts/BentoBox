import SwiftUI
import SwiftData

struct ChartsView: View {
    let profile: UserProfile

    @Query(sort: \LoggedEntry.date) private var allLoggedEntries: [LoggedEntry]
    @Query(sort: \BodyMetricEntry.date) private var allWeightEntries: [BodyMetricEntry]
    @State private var rangeDays = 30
    @State private var weekCardsOffset = 0

    private var loggedEntries: [LoggedEntry] {
        allLoggedEntries.filter { $0.mealSlot?.profile?.id == profile.id }
    }

    private var weightEntries: [BodyMetricEntry] {
        allWeightEntries.filter { $0.profile?.id == profile.id }
    }

    private var summary: ChartsViewModel {
        ChartsViewModel(profile: profile, loggedEntries: loggedEntries, rangeDays: rangeDays)
    }

    /// Independent of `rangeDays` — a fixed Mon–Sun calendar week with its own back/forward
    /// navigation, since the weekly cards need real week boundaries (empty future-day bars)
    /// rather than a trailing-N-days window.
    private var weeklyCards: WeeklyCardsViewModel {
        WeeklyCardsViewModel(profile: profile, loggedEntries: loggedEntries, weekOffset: weekCardsOffset)
    }

    private var weeklyInsights: WeeklyInsights {
        InsightsCalculator.weeklyInsights(
            calorieTrendPoints: summary.calorieTrendPoints,
            target: summary.calorieTarget,
            weightEntries: weightEntries
        )
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

                Section {
                    InsightsCardView(insights: weeklyInsights, weightUnit: profile.weightUnit)
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

                Section {
                    WeekNavigationHeaderView(
                        weekStart: weeklyCards.weekStart,
                        onPrevious: { weekCardsOffset -= 1 },
                        onNext: { weekCardsOffset += 1 }
                    )
                    CaloriesWeekCardView(summary: weeklyCards)
                    MacronutrientsWeekCardView(summary: weeklyCards)
                }
                .listRowBackground(Color.clear)
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

private struct InsightsCardView: View {
    let insights: WeeklyInsights
    let weightUnit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                InsightStatView(value: "\(insights.daysOnTarget + insights.daysUnderTarget)", label: "on track", color: .accentColor)
                InsightStatView(value: "\(insights.daysOverTarget)", label: "over target", color: .brandProtein)
                InsightStatView(value: "\(Int(insights.averagePercentOfTarget))%", label: "avg of target", color: .brandCarbs)
                Spacer()
            }

            if let weightChangeKG = insights.weightChangeKG {
                Divider()
                Label(weightTrendDescription(deltaKG: weightChangeKG), systemImage: weightChangeKG <= 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(weightChangeKG <= 0 ? Color.accentColor : Color.brandProtein)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func weightTrendDescription(deltaKG: Double) -> String {
        let magnitude = abs(deltaKG)
        guard magnitude >= 0.1 else { return "Weight steady this week" }
        let direction = deltaKG < 0 ? "down" : "up"
        return "Weight \(direction) \(weightUnit.displayString(fromKG: magnitude)) this week"
    }
}

private struct InsightStatView: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
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

private struct WeekNavigationHeaderView: View {
    let weekStart: Date
    var onPrevious: () -> Void
    var onNext: () -> Void

    private var weekEnd: Date {
        Calendar.current.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    private var rangeText: String {
        let sameMonth = Calendar.current.isDate(weekStart, equalTo: weekEnd, toGranularity: .month)
        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = sameMonth
            ? weekEnd.formatted(.dateTime.day())
            : weekEnd.formatted(.dateTime.month(.abbreviated).day())
        return "\(startText) – \(endText)"
    }

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(rangeText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
    }
}
