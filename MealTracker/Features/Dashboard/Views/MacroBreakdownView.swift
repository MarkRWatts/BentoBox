import SwiftUI

struct MacroBreakdownView: View {
    let summary: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            MacroRow(name: "Protein", consumed: summary.consumedProtein, target: summary.macroTargets.proteinGrams, color: .red)
            MacroRow(name: "Carbs", consumed: summary.consumedCarbs, target: summary.macroTargets.carbGrams, color: .orange)
            MacroRow(name: "Fat", consumed: summary.consumedFat, target: summary.macroTargets.fatGrams, color: .yellow)
        }
    }
}

private struct MacroRow: View {
    let name: String
    let consumed: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(consumed / target, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Int(consumed))g / \(Int(target))g")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)

            ProgressView(value: progress)
                .tint(color)
        }
    }
}
