import SwiftUI
import Charts

struct CalorieSummaryRingView: View {
    let summary: DashboardViewModel

    private var consumed: Double { max(summary.consumedCalories, 0) }
    private var remaining: Double { max(summary.calorieTarget - summary.consumedCalories, 0) }

    private var ringGradient: AngularGradient {
        AngularGradient(colors: [.brandForest, .accentColor, .brandCarbs], center: .center, startAngle: .degrees(0), endAngle: .degrees(360))
    }

    var body: some View {
        VStack(spacing: 8) {
            Chart {
                SectorMark(angle: .value("Consumed", consumed), innerRadius: .ratio(0.7), angularInset: 1.5)
                    .foregroundStyle(ringGradient)
                    .cornerRadius(6)
                SectorMark(angle: .value("Remaining", remaining), innerRadius: .ratio(0.7), angularInset: 1.5)
                    .foregroundStyle(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
            }
            .frame(width: 200, height: 200)
            .chartBackground { _ in
                VStack(spacing: 2) {
                    Text("\(Int(summary.consumedCalories))")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("of \(Int(summary.calorieTarget)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(summary.remainingCalories >= 0
                 ? "\(Int(summary.remainingCalories)) cal remaining"
                 : "\(Int(-summary.remainingCalories)) cal over")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(summary.remainingCalories >= 0 ? Color.accentColor : Color.brandProtein)

            if let delta = summary.calorieCyclingDeltaToday {
                Text(delta > 0 ? "+\(Int(delta)) cal today (cycling)" : "\(Int(delta)) cal today (cycling)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
