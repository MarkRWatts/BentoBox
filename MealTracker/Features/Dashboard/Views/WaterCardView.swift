import SwiftUI
import SwiftData

/// "WATER" card — a row of glass glyphs over the same small-caps-header/rounded-card shape
/// `MicronutrientBreakdownView` uses, so hydration reads as one more nutrition row on the
/// Dashboard rather than a differently-styled bolt-on. Its accent is `dashboardWater` blue
/// rather than the Dashboard's green: water is the one metric here that already has a colour
/// people expect. Logging is one tap of the trailing button
/// (one glass, sized in Settings) and the minus button removes the most recent glass, which is
/// what "I tapped twice by accident" actually needs — there's no per-drink editing screen here.
struct WaterCardView: View {
    let profile: UserProfile
    /// The viewed day's entries only — `DashboardView` does the date filtering, matching how it
    /// already hands `selectedDayEntries` to the food cards.
    let entries: [WaterLogEntry]
    /// The day being viewed, so a glass logged while browsing yesterday lands on yesterday.
    let date: Date

    @Environment(\.modelContext) private var modelContext

    private var consumedML: Double { entries.reduce(0) { $0 + $1.volumeML } }
    private var unit: VolumeUnit { profile.volumeUnit }
    private var servingML: Double { max(profile.waterServingML, 1) }

    private var progress: Double {
        WaterIntakeCalculator.progress(consumedML: consumedML, targetML: profile.dailyWaterTargetML)
    }

    private var glassCount: Int {
        WaterIntakeCalculator.glassesInTarget(targetML: profile.dailyWaterTargetML, servingML: servingML)
    }

    private var glassesFilled: Int {
        WaterIntakeCalculator.glassesCompleted(consumedML: consumedML, servingML: servingML)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WATER")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardInkSecondary)
                Spacer()
                (Text("\(Int(unit.value(fromML: consumedML).rounded()))").foregroundStyle(Color.dashboardWater)
                    + Text(" / \(Int(unit.value(fromML: profile.dailyWaterTargetML).rounded())) \(unit.displayName)")
                        .foregroundStyle(Color.dashboardInkSecondary))
                    .font(.manrope(12, weight: .semibold))
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                glassRow

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.dashboardBarTrack)
                        Capsule().fill(Color.dashboardWater).frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)

                HStack(spacing: 12) {
                    Button {
                        removeLastGlass()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(entries.isEmpty ? Color.dashboardInkFaint : Color.dashboardInk)
                            .frame(width: 34, height: 34)
                            .background(Color.dashboardBarTrack, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(entries.isEmpty)
                    .accessibilityLabel("Remove last glass")

                    Spacer()

                    Button {
                        addGlass()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .bold))
                            Text(unit.displayString(fromML: servingML))
                                .font(.manrope(13, weight: .semibold))
                        }
                        .foregroundStyle(Color.dashboardCard)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Color.dashboardWater, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Log a \(unit.displayString(fromML: servingML)) glass")
                }
            }
            .padding(16)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var glassRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<glassCount, id: \.self) { index in
                Image(systemName: index < glassesFilled ? "drop.fill" : "drop")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(index < glassesFilled ? Color.dashboardWaterFill(index, of: glassCount) : Color.dashboardInkFaint)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Water")
        .accessibilityValue("\(unit.displayString(fromML: consumedML)) of \(unit.displayString(fromML: profile.dailyWaterTargetML))")
    }

    /// Timestamped with the viewed day at the current time of day — the same `atCurrentTimeOfDay`
    /// rule food logging uses, so backfilling yesterday's water doesn't stamp everything midnight.
    private func addGlass() {
        let entry = WaterLogEntry(date: date.atCurrentTimeOfDay, volumeML: servingML, profile: profile)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    private func removeLastGlass() {
        guard let latest = entries.max(by: { $0.date < $1.date }) else { return }
        modelContext.delete(latest)
        try? modelContext.save()
    }
}
