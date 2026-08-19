import SwiftUI
import Charts

/// Cronometer-style weekly macronutrients card: today's Fat/Carbs/Protein split as a pie, a
/// Mon–Sun stacked bar strip for the navigated week, and the week's average split.
struct MacronutrientsWeekCardView: View {
    let summary: WeeklyCardsViewModel

    private var todayPercents: (protein: Double, carbs: Double, fat: Double) {
        summary.todayMacroPercents
    }

    private var averagePercents: (protein: Double, carbs: Double, fat: Double) {
        summary.averageMacroPercents
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrients")
                .font(.archivo(17, weight: .semibold))
                .foregroundStyle(Color.dashboardInk)

            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Chart {
                        SectorMark(angle: .value("Fat", max(todayPercents.fat, 0.0001)), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(Color.brandFat)
                            .cornerRadius(3)
                        SectorMark(angle: .value("Carbs", max(todayPercents.carbs, 0.0001)), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(Color.brandCarbs)
                            .cornerRadius(3)
                        SectorMark(angle: .value("Protein", max(todayPercents.protein, 0.0001)), innerRadius: .ratio(0.6), angularInset: 1.5)
                            .foregroundStyle(Color.brandProtein)
                            .cornerRadius(3)
                    }
                    // Swift Charts reserves its own internal margin around the plot area, so
                    // just setting `.frame` here renders visibly smaller than the plain-Shape
                    // ring in CaloriesWeekCardView at the same frame size. `.chartPlotStyle`
                    // pins the actual drawn plot area — not the outer view — to that size, so
                    // the two circular graphs read as the same size.
                    .chartPlotStyle { plotArea in
                        plotArea.frame(width: CaloriesWeekCardView.circleSize, height: CaloriesWeekCardView.circleSize)
                    }
                    .frame(width: CaloriesWeekCardView.circleSize, height: CaloriesWeekCardView.circleSize)

                    MacroLegendRow(name: "Fat", color: .brandFat, percent: todayPercents.fat)
                    MacroLegendRow(name: "Carbs", color: .brandCarbs, percent: todayPercents.carbs)
                    MacroLegendRow(name: "Protein", color: .brandProtein, percent: todayPercents.protein)
                }
                // Matches CaloriesWeekCardView's left column width so both cards' bar strips
                // start at the same x position.
                .frame(width: CaloriesWeekCardView.leftColumnWidth, alignment: .leading)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(summary.dailyPoints) { point in
                        MacroDayStackView(point: point)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("AVG")
                    .font(.manrope(11, weight: .bold))
                    .foregroundStyle(Color.dashboardInkSecondary)
                MacroPercentChip(color: .brandFat, percent: averagePercents.fat)
                MacroPercentChip(color: .brandCarbs, percent: averagePercents.carbs)
                MacroPercentChip(color: .brandProtein, percent: averagePercents.protein)
            }
        }
        .padding()
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

private struct MacroLegendRow: View {
    let name: String
    let color: Color
    let percent: Double

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(name)
                .font(.manrope(11, weight: .medium))
                .foregroundStyle(Color.dashboardInk)
            Spacer(minLength: 4)
            Text("\(Int(percent.rounded()))%")
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(Color.dashboardInkSecondary)
        }
    }
}

private struct MacroPercentChip: View {
    let color: Color
    let percent: Double

    var body: some View {
        Text("\(Int(percent.rounded()))%")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct MacroDayStackView: View {
    let point: DailyMacroPoint

    private let barWidth: CGFloat = 12
    private let barMaxHeight: CGFloat = 64

    private var proteinKcal: Double { point.proteinGrams * 4 }
    private var carbKcal: Double { point.carbGrams * 4 }
    private var fatKcal: Double { point.fatGrams * 9 }
    private var totalKcal: Double { proteinKcal + carbKcal + fatKcal }

    var body: some View {
        VStack(spacing: 4) {
            if point.hasEntries && totalKcal > 0 {
                VStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brandFat)
                        .frame(width: barWidth, height: max(2, barMaxHeight * fatKcal / totalKcal))
                    Rectangle()
                        .fill(Color.brandCarbs)
                        .frame(width: barWidth, height: max(2, barMaxHeight * carbKcal / totalKcal))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brandProtein)
                        .frame(width: barWidth, height: max(2, barMaxHeight * proteinKcal / totalKcal))
                }
                .frame(height: barMaxHeight, alignment: .bottom)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.dashboardBarTrack)
                    .frame(width: barWidth, height: barMaxHeight)
            }

            Text(point.date.formatted(.dateTime.weekday(.narrow)))
                .font(.manrope(10, weight: .semibold))
                .foregroundStyle(Calendar.current.isDateInToday(point.date) ? Color.dashboardAccentDeep : Color.dashboardInkFaint)
        }
    }
}
