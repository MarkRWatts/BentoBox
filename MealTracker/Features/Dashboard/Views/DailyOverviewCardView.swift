import SwiftUI

/// Hero card for the dashboard — a literal port of the Claude Design "full-width bars" (1a)
/// calorie-tracker mockup: today's consumed-calorie headline and a trailing 7-day intake strip
/// with a dashed per-day target line. The mockup only ever shows a positive ("N left today")
/// state; going over budget isn't something it designed for, so that case borrows the app's
/// existing `Color.brandProtein` "over" convention (used the same way in `MacroBreakdownView` and
/// `CaloriesWeekCardView`) rather than inventing an unspecified color.
struct DailyOverviewCardView: View {
    let summary: DashboardViewModel
    /// Oldest to newest, ending on the viewed day.
    let recentDayProgress: [DayProgress]
    let selectedDate: Date

    private var isOverBudget: Bool { summary.remainingCalories < 0 }

    /// "820 left today" or "240 over today" — the remaining/over amount lives in this caption
    /// now that the headline number above it is always total calories consumed. Built as `Text`
    /// (rather than a plain `String`) so the interpolated number still gets the automatic
    /// locale-grouped formatting `Text` applies to numbers embedded directly in it — a plain
    /// `String` built via `"\(Int(...))"` wouldn't pick that up.
    private var remainingCaptionText: Text {
        isOverBudget
            ? Text("\(Int(abs(summary.remainingCalories))) over today")
            : Text("\(Int(summary.remainingCalories)) left today")
    }

    private var averageIntake: Double {
        let loggedDays = recentDayProgress.filter { $0.hasEntries }
        guard !loggedDays.isEmpty else { return 0 }
        return loggedDays.reduce(0) { $0 + $1.caloriesConsumed } / Double(loggedDays.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    (Text("\(Int(summary.consumedCalories))").font(.archivo(62, weight: .semibold))
                        + Text(" kcal").font(.manrope(20, weight: .semibold)))
                        .foregroundStyle(Color.dashboardInk)
                    remainingCaptionText
                        .font(.manrope(12, weight: .semibold))
                        .tracking(0.24)
                        .foregroundStyle(isOverBudget ? Color.brandProtein : Color.dashboardAccent)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("7-DAY INTAKE")
                        .font(.manrope(10, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(Color.dashboardInkSecondary)
                    Text("avg \(Int(averageIntake))")
                        .font(.manrope(11.5, weight: .medium))
                        .foregroundStyle(Color.dashboardAccent)
                }
            }

            DailyIntakeBarsView(points: recentDayProgress, selectedDate: selectedDate)
                .padding(.top, 20)
        }
        .padding(.top, 26)
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 30))
        .accessibilityElement(children: .combine)
    }
}

/// Trailing 7-day calorie bar strip with a dashed line through each day's own target, matching
/// the mockup's bar chart pixel-for-pixel (132pt tall, 7pt gaps, top-only 6pt rounding).
private struct DailyIntakeBarsView: View {
    let points: [DayProgress]
    let selectedDate: Date

    private let barSpacing: CGFloat = 7
    private let barMaxHeight: CGFloat = 132

    private var maxScale: Double {
        let values = points.flatMap { [$0.caloriesConsumed, $0.caloriesTarget] }
        return max((values.max() ?? 0) * 1.1, 1)
    }

    private func fillHeight(for point: DayProgress) -> CGFloat {
        guard point.hasEntries else { return 0 }
        return max(3, CGFloat(point.caloriesConsumed / maxScale) * barMaxHeight)
    }

    private func targetFraction(for point: DayProgress) -> CGFloat {
        CGFloat(min(point.caloriesTarget / maxScale, 1))
    }

    private func barColor(for point: DayProgress) -> Color {
        if point.hasEntries && point.caloriesConsumed > point.caloriesTarget { return .brandProtein }
        if Calendar.current.isDate(point.date, inSameDayAs: selectedDate) { return .dashboardAccent }
        return .dashboardBarFill
    }

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { geometry in
                let barWidth = (geometry.size.width - barSpacing * CGFloat(points.count - 1)) / CGFloat(points.count)
                ZStack(alignment: .bottomLeading) {
                    HStack(spacing: barSpacing) {
                        ForEach(points) { point in
                            dayBar(point, width: barWidth)
                        }
                    }
                    targetTrendLine(barWidth: barWidth)
                }
            }
            .frame(height: barMaxHeight)

            HStack(spacing: barSpacing) {
                ForEach(points) { point in
                    Text(point.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.manrope(10, weight: .semibold))
                        .foregroundStyle(Calendar.current.isDate(point.date, inSameDayAs: selectedDate) ? Color.dashboardAccentDeep : Color.dashboardInkFaint)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func dayBar(_ point: DayProgress, width: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                .fill(Color.dashboardBarTrack)
            if point.hasEntries {
                UnevenRoundedRectangle(topLeadingRadius: 6, topTrailingRadius: 6)
                    .fill(barColor(for: point))
                    .frame(height: fillHeight(for: point))
            }
        }
        .frame(width: width, height: barMaxHeight)
    }

    private func targetTrendLine(barWidth: CGFloat) -> some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
                let y = barMaxHeight - targetFraction(for: point) * barMaxHeight
                let position = CGPoint(x: x, y: y)
                index == 0 ? path.move(to: position) : path.addLine(to: position)
            }
        }
        .stroke(Color.dashboardLime.opacity(0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 3]))
        .accessibilityHidden(true)
    }
}
