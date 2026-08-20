import SwiftUI

/// Fiber, sugar, saturated fat, and sodium — captured on every `FoodItem` today (manual entry,
/// barcode lookup, and label scan all already populate these fields) but never surfaced anywhere
/// until now. Styled as a card of rows beneath `MacroBreakdownView`, matching `LoggedMealsCardView`'s
/// "small caps header + divided rows" shape rather than the macros' 3-up grid, since four rows of
/// name/value/bar read better stacked than squeezed into equal-width boxes.
struct MicronutrientBreakdownView: View {
    let summary: DashboardViewModel

    private var rows: [NutrientRow] {
        let targets = summary.micronutrientTargets
        return [
            NutrientRow(name: "Fiber", consumed: summary.consumedFiber, target: targets.fiberGrams, unit: "g"),
            NutrientRow(name: "Sugar", consumed: summary.consumedSugar, target: targets.sugarGrams, unit: "g"),
            NutrientRow(name: "Saturated Fat", consumed: summary.consumedSaturatedFat, target: targets.saturatedFatGrams, unit: "g"),
            NutrientRow(name: "Sodium", consumed: summary.consumedSodiumMg, target: targets.sodiumMg, unit: "mg")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MORE NUTRITION")
                .font(.manrope(10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.dashboardInkSecondary)
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.element.name) { index, row in
                    row

                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(Color.dashboardDivider)
                            .frame(height: 1)
                    }
                }
            }
            .padding(16)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}

private struct NutrientRow: View {
    let name: String
    let consumed: Double
    let target: Double
    let unit: String

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Spacer()
                (Text("\(Int(consumed.rounded()))").foregroundStyle(Color.dashboardInk)
                    + Text(" / \(Int(target.rounded())) \(unit)").foregroundStyle(Color.dashboardInkSecondary))
                    .font(.manrope(12, weight: .semibold))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.dashboardBarTrack)
                    Capsule().fill(Color.dashboardAccent).frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue("\(Int(consumed.rounded())) of \(Int(target.rounded())) \(unit)")
    }
}
