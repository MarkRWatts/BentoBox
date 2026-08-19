import SwiftUI

struct MacroBreakdownView: View {
    let summary: DashboardViewModel

    private var isOverCalories: Bool { summary.consumedCalories > summary.calorieTarget }

    var body: some View {
        VStack(spacing: 12) {
            MacroRow(
                name: "Calories",
                consumed: summary.consumedCalories,
                target: summary.calorieTarget,
                color: isOverCalories ? .brandProtein : .accentColor,
                valueText: "\(Int(summary.consumedCalories)) / \(Int(summary.calorieTarget)) cal",
                accessibilityUnit: "calories"
            )
            MacroRow(name: "Protein", consumed: summary.consumedProtein, target: summary.macroTargets.proteinGrams, color: .brandProtein)
            MacroRow(name: "Carbs", consumed: summary.consumedCarbs, target: summary.macroTargets.carbGrams, color: .brandCarbs)
            MacroRow(name: "Fat", consumed: summary.consumedFat, target: summary.macroTargets.fatGrams, color: .brandFat)
        }
    }
}

private struct MacroRow: View {
    let name: String
    let consumed: Double
    let target: Double
    let color: Color
    var valueText: String?
    var accessibilityUnit: String = "grams"

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(name)
                Spacer()
                Text(valueText ?? "\(Int(consumed))g / \(Int(target))g")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ProgressView(value: progress)
                .tint(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue("\(Int(consumed)) of \(Int(target)) \(accessibilityUnit)")
    }
}
