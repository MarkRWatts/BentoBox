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
                    Text("Trends")
                        .font(.archivo(30, weight: .semibold))
                        .foregroundStyle(Color.dashboardInk)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)

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
                .listRowInsets(EdgeInsets())

                Section {
                    VerdictCardView(insights: weeklyInsights, target: summary.calorieTarget, weightUnit: profile.weightUnit)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if profile.isAdaptiveCalorieTargetEnabled {
                    Section {
                        AdaptiveTDEECardView(profile: profile, loggedEntries: loggedEntries, weightEntries: weightEntries)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

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
                .listRowBackground(Color.dashboardCard)

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
            .scrollContentBackground(.hidden)
            .background(Color.dashboardCanvas)
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Kept technically visible (never `.toolbar(.hidden, for: .navigationBar)`) rather
            // than toggled hidden — a List nested in a TabView's per-tab NavigationStack has a
            // known SwiftUI/iOS 26 bug where hiding the nav bar replays its hide animation on
            // every tab re-selection, producing a visible stutter on every switch (see
            // https://developer.apple.com/forums/thread/758923). Only the background and title
            // are hidden here, which sidesteps that hide/show state machine entirely and leaves
            // push/pop transitions elsewhere untouched.
            .toolbarBackground(.hidden, for: .navigationBar)
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
                    .font(.archivo(22, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text(streakDays > 0 ? "Logging streak" : "Log a meal to start a streak")
                    .font(.manrope(12, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

/// A literal port of the Claude Design mockup's "Weekly progress" screen (1e) hero: a
/// plain-language verdict sentence over two headline stats, on the same dark-emerald surface as
/// the mockup rather than a neutral card — matching `Color.dashboardAccentDeep`'s role elsewhere
/// (the Dashboard's "today" bar/weekday, the Add Food floating button).
private struct VerdictCardView: View {
    let insights: WeeklyInsights
    let target: Double
    let weightUnit: WeightUnit

    private var onTrackDays: Int { insights.daysOnTarget + insights.daysUnderTarget }
    private var totalDays: Int { onTrackDays + insights.daysOverTarget }

    private var verdictSentence: String {
        guard totalDays > 0 else { return "Log a few days to see your weekly verdict." }
        return "You stayed inside your budget \(onTrackDays) day\(onTrackDays == 1 ? "" : "s") out of \(totalDays)."
    }

    private var vsTargetDelta: Double { insights.averageCalories - target }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VERDICT")
                .font(.manrope(10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.6))

            Text(verdictSentence)
                .font(.archivo(26, weight: .semibold))
                .foregroundStyle(.white)

            if totalDays > 0 {
                HStack(spacing: 26) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(insights.averageCalories))")
                            .font(.archivo(24, weight: .semibold))
                            .foregroundStyle(Color.dashboardOnAccent)
                        Text("avg / day")
                            .font(.manrope(10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vsTargetDelta <= 0 ? "−\(Int(abs(vsTargetDelta)))" : "+\(Int(vsTargetDelta))")
                            .font(.archivo(24, weight: .semibold))
                            .foregroundStyle(Color.dashboardOnAccent)
                        Text("vs target")
                            .font(.manrope(10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
            }

            if let weightChangeKG = insights.weightChangeKG {
                Rectangle().fill(.white.opacity(0.15)).frame(height: 1)
                Label(weightTrendDescription(deltaKG: weightChangeKG), systemImage: weightChangeKG <= 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.manrope(12.5, weight: .medium))
                    .foregroundStyle(Color.dashboardOnAccent)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardAccentDeep, in: RoundedRectangle(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private func weightTrendDescription(deltaKG: Double) -> String {
        let magnitude = abs(deltaKG)
        guard magnitude >= 0.1 else { return "Weight steady this week" }
        let direction = deltaKG < 0 ? "down" : "up"
        return "Weight \(direction) \(weightUnit.displayString(fromKG: magnitude)) this week"
    }
}

/// Shows the calorie target actually driving the day (the weekly-cached
/// `profile.adaptiveCalorieTarget` — see `DashboardView.recalculateAdaptiveTargetIfNeeded`)
/// alongside a freshly-computed breakdown of what's currently feeding it. The two can differ
/// slightly during the week as new logs/weigh-ins come in; the headline number only catches up
/// once a week by design, so today's budget doesn't jitter with every entry.
private struct AdaptiveTDEECardView: View {
    let profile: UserProfile
    let loggedEntries: [LoggedEntry]
    let weightEntries: [BodyMetricEntry]

    private var liveEstimate: AdaptiveTDEECalculator.Result? {
        let dailyCalories = Dictionary(grouping: loggedEntries, by: { $0.date.startOfDay })
            .mapValues { $0.reduce(0) { $0 + $1.calories } }
        let weights = weightEntries.map { (date: $0.date.startOfDay, weightKG: $0.weightKG) }
        return AdaptiveTDEECalculator.estimate(dailyCalories: dailyCalories, weightEntries: weights)
    }

    private func weightTrendText(kgPerWeek: Double) -> String {
        let magnitude = abs(kgPerWeek)
        guard magnitude >= 0.05 else { return "steady" }
        let direction = kgPerWeek < 0 ? "down" : "up"
        return "\(direction) \(profile.weightUnit.displayString(fromKG: magnitude))/wk"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADAPTIVE TARGET")
                .font(.manrope(10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.dashboardInkSecondary)

            if let target = profile.adaptiveCalorieTarget {
                Text("\(Int(target)) kcal")
                    .font(.archivo(26, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                if let updatedAt = profile.adaptiveCalorieTargetUpdatedAt {
                    Text("Updated \(updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.manrope(11, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
                if let liveEstimate {
                    Rectangle().fill(Color.dashboardDivider).frame(height: 1).padding(.vertical, 2)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(liveEstimate.averageDailyCalories))")
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(Color.dashboardInk)
                            Text("14-day avg intake")
                                .font(.manrope(10, weight: .medium))
                                .foregroundStyle(Color.dashboardInkSecondary)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(weightTrendText(kgPerWeek: liveEstimate.weightTrendKGPerWeek))
                                .font(.manrope(14, weight: .semibold))
                                .foregroundStyle(Color.dashboardInk)
                            Text("Weight trend")
                                .font(.manrope(10, weight: .medium))
                                .foregroundStyle(Color.dashboardInkSecondary)
                        }
                    }
                }
            } else {
                Text("Gathering data")
                    .font(.archivo(20, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text("Needs \(AdaptiveTDEECalculator.minimumDays) days of logged food and 2+ weigh-ins — your target stays on the standard formula until then.")
                    .font(.manrope(12, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 20))
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
                .font(.manrope(13, weight: .semibold))
                .foregroundStyle(Color.dashboardInkSecondary)
            Spacer()
            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
        }
        .buttonStyle(.plain)
    }
}
