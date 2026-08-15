import SwiftUI
import Charts

struct CalorieSummaryRingView: View {
    let summary: DashboardViewModel

    private var consumed: Double { max(summary.consumedCalories, 0) }
    private var remaining: Double { max(summary.calorieTarget - summary.consumedCalories, 0) }

    var body: some View {
        VStack(spacing: 8) {
            Chart {
                SectorMark(angle: .value("Consumed", consumed), innerRadius: .ratio(0.7), angularInset: 1.5)
                    .foregroundStyle(Color.accentColor)
                SectorMark(angle: .value("Remaining", remaining), innerRadius: .ratio(0.7), angularInset: 1.5)
                    .foregroundStyle(Color.secondary.opacity(0.2))
            }
            .frame(width: 200, height: 200)
            .chartBackground { _ in
                VStack {
                    Text("\(Int(summary.consumedCalories))")
                        .font(.title.bold())
                    Text("of \(Int(summary.calorieTarget)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summary.remainingCalories >= 0
                 ? "\(Int(summary.remainingCalories)) cal remaining"
                 : "\(Int(-summary.remainingCalories)) cal over")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
