import SwiftUI

/// Cronometer-style weekly calories card: a ring for today's progress, a Mon–Sun bar strip for
/// the navigated week (on one shared calorie scale, with a trend line through each day's own
/// target so calorie cycling is visible), and a weekly budget summary line.
struct CaloriesWeekCardView: View {
    let summary: WeeklyCardsViewModel

    /// Shared with `MacronutrientsWeekCardView` so the two cards' circular graphs read as the
    /// same size, and so the bars below start at the same x position in both cards.
    static let circleSize: CGFloat = 80
    static let leftColumnWidth: CGFloat = 108

    private var todayFraction: Double {
        guard summary.todayCalorieTarget > 0 else { return 0 }
        return min(summary.todayConsumedCalories / summary.todayCalorieTarget, 1)
    }

    private var todayDelta: Double {
        summary.todayCalorieTarget - summary.todayConsumedCalories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calories")
                .font(.archivo(17, weight: .semibold))
                .foregroundStyle(Color.dashboardInk)

            HStack(alignment: .center, spacing: 20) {
                // Leading-aligned to match MacronutrientsWeekCardView's left column — both
                // circles need the same alignment within the same-width column, or their
                // centers land at different x offsets even though the columns are equal width.
                VStack(alignment: .leading, spacing: 4) {
                    ZStack {
                        RingProgressView(
                            progress: todayFraction,
                            lineWidth: 9,
                            trackColor: Color.dashboardBarTrack,
                            progressColor: todayDelta >= 0 ? .dashboardAccent : .brandProtein
                        )
                        // The stroke bleeds lineWidth/2 outside the shape's own bounding circle,
                        // so without this the ring's true visual diameter would overshoot
                        // `circleSize` — inset first so the outer edge lands exactly on it,
                        // matching the pie's `.chartPlotStyle`-pinned diameter below.
                        .padding(4.5)
                        VStack(spacing: 0) {
                            Text("\(Int(abs(todayDelta)))")
                                .font(.archivo(17, weight: .semibold))
                                .foregroundStyle(todayDelta >= 0 ? Color.dashboardAccent : Color.brandProtein)
                            Text(todayDelta >= 0 ? "Under" : "Over")
                                .font(.manrope(11, weight: .medium))
                                .foregroundStyle(Color.dashboardInkSecondary)
                        }
                    }
                    .frame(width: Self.circleSize, height: Self.circleSize)
                    Text("\(Int(summary.todayConsumedCalories)) cals")
                        .font(.manrope(12, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
                .frame(width: Self.leftColumnWidth, alignment: .leading)

                CalorieWeekBarsView(points: summary.dailyPoints)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(weeklyBudgetText)
                .font(.manrope(13, weight: .medium))
                .foregroundStyle(Color.dashboardInkSecondary)
        }
        .padding()
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private var weeklyBudgetText: String {
        let delta = summary.weeklyCalorieBudgetDelta
        return delta >= 0
            ? "\(Int(delta)) under budget for week"
            : "\(Int(-delta)) over budget for week"
    }
}

/// The bar strip plus a dashed trend line through each day's own calorie target. All 7 days
/// share one absolute calorie scale (rather than each bar being normalized to its own target) —
/// that's what makes the target line meaningful to look at when calorie cycling gives different
/// days different targets; on a per-day-normalized scale the line would always be flat.
private struct CalorieWeekBarsView: View {
    let points: [DailyMacroPoint]

    private let barWidth: CGFloat = 12
    private let barSpacing: CGFloat = 6
    private let barMaxHeight: CGFloat = 64

    private var totalWidth: CGFloat {
        CGFloat(points.count) * barWidth + CGFloat(max(points.count - 1, 0)) * barSpacing
    }

    /// The scale all bars and the trend line are drawn against — the week's highest calorie
    /// figure (consumed or target) plus headroom, so nothing clips and the line stays legible.
    private var maxScale: Double {
        let values = points.flatMap { [$0.calories, $0.calorieTarget] }
        return max((values.max() ?? 0) * 1.1, 1)
    }

    private func xCenter(forIndex index: Int) -> CGFloat {
        CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
    }

    private func fillHeight(for point: DailyMacroPoint) -> CGFloat {
        max(2, CGFloat(point.calories / maxScale) * barMaxHeight)
    }

    private func targetY(for point: DailyMacroPoint) -> CGFloat {
        barMaxHeight - CGFloat(min(point.calorieTarget / maxScale, 1)) * barMaxHeight
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottomLeading) {
                HStack(spacing: barSpacing) {
                    ForEach(points) { point in
                        CalorieDayBarView(point: point, barWidth: barWidth, barMaxHeight: barMaxHeight, fillHeight: fillHeight(for: point))
                    }
                }
                targetTrendLine
            }
            .frame(width: totalWidth, height: barMaxHeight + 8, alignment: .bottom)

            HStack(spacing: barSpacing) {
                ForEach(points) { point in
                    Text(point.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.manrope(10, weight: .semibold))
                        .foregroundStyle(Calendar.current.isDateInToday(point.date) ? Color.dashboardAccentDeep : Color.dashboardInkFaint)
                        .frame(width: barWidth)
                }
            }
        }
    }

    private var targetTrendLine: some View {
        Path { path in
            for (index, point) in points.enumerated() {
                let position = CGPoint(x: xCenter(forIndex: index), y: targetY(for: point))
                if index == 0 {
                    path.move(to: position)
                } else {
                    path.addLine(to: position)
                }
            }
        }
        .stroke(Color.dashboardLime.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [4, 3]))
        .frame(width: totalWidth, height: barMaxHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

private struct CalorieDayBarView: View {
    let point: DailyMacroPoint
    let barWidth: CGFloat
    let barMaxHeight: CGFloat
    let fillHeight: CGFloat

    private var isOver: Bool { point.hasEntries && point.calories > point.calorieTarget }
    private var isUnderFinished: Bool { point.hasEntries && !isOver }

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.dashboardBarTrack)
                .frame(width: barWidth, height: barMaxHeight)

            if point.hasEntries {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isOver ? Color.brandProtein : Color.dashboardBarFill)
                    .frame(width: barWidth, height: fillHeight)
            }
        }
        .overlay(alignment: .bottom) {
            if isUnderFinished {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Color.dashboardAccent, in: Circle())
                    .offset(y: -(fillHeight + 7))
            }
        }
        .frame(width: barWidth, height: barMaxHeight + 8, alignment: .bottom)
    }
}
