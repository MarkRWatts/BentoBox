import SwiftUI

/// Three-up macro grid, a literal port of the mockup's macro cards: percent-of-target headline
/// over a thin track/fill bar. Calories live in `DailyOverviewCardView`'s hero number instead of
/// being folded in here as a fourth bar.
struct MacroBreakdownView: View {
    let summary: DashboardViewModel

    var body: some View {
        HStack(spacing: 10) {
            MacroCard(name: "Protein", consumed: summary.consumedProtein, target: summary.macroTargets.proteinGrams, color: .dashboardAccent)
            MacroCard(name: "Carbs", consumed: summary.consumedCarbs, target: summary.macroTargets.carbGrams, color: .dashboardCarbFill)
            MacroCard(name: "Fat", consumed: summary.consumedFat, target: summary.macroTargets.fatGrams, color: .dashboardLime)
        }
    }
}

private struct MacroCard: View {
    let name: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    private var percent: Int {
        guard target > 0 else { return 0 }
        return Int((consumed / target * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name.uppercased())
                .font(.manrope(9, weight: .bold))
                .tracking(1.08)
                .foregroundStyle(Color.dashboardInkSecondary)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dashboardBarTrack)
                    Capsule().fill(color).frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 5)

            (Text("\(percent)").foregroundStyle(Color.dashboardInk) + Text("%").foregroundStyle(Color.dashboardInkSecondary))
                .font(.manrope(12, weight: .semibold))
        }
        .padding(.top, 13)
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue("\(Int(consumed)) of \(Int(target)) grams, \(percent) percent")
    }
}
