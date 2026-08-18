import SwiftUI

/// A small two-ring glyph: outer ring = calories, inner ring = protein. Two rings, not three or
/// four — at the ~30pt size this renders in (week strip, month grid), more concentric rings than
/// that stop reading as distinct strokes. Protein gets the second ring because it's already this
/// app's "hero" macro elsewhere (dedicated per-kg override, listed first in `MacroBreakdownView`).
struct DayProgressRingGlyph: View {
    let progress: DayProgress
    var size: CGFloat = 30

    private var calorieFraction: Double {
        guard progress.caloriesTarget > 0 else { return 0 }
        return min(progress.caloriesConsumed / progress.caloriesTarget, 1)
    }

    private var proteinFraction: Double {
        guard progress.proteinTarget > 0 else { return 0 }
        return min(progress.proteinConsumed / progress.proteinTarget, 1)
    }

    private var isOverCalories: Bool {
        progress.caloriesConsumed > progress.caloriesTarget
    }

    var body: some View {
        ZStack {
            RingProgressView(
                progress: progress.hasEntries ? calorieFraction : 0,
                lineWidth: size * 0.14,
                trackColor: .secondary.opacity(0.15),
                progressColor: isOverCalories ? .brandProtein : .accentColor
            )
            RingProgressView(
                progress: progress.hasEntries ? proteinFraction : 0,
                lineWidth: size * 0.10,
                trackColor: .secondary.opacity(0.10),
                progressColor: .brandProtein
            )
            .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 12) {
        DayProgressRingGlyph(progress: DayProgress(id: .now, date: .now, caloriesConsumed: 1200, caloriesTarget: 2000, proteinConsumed: 80, proteinTarget: 130, hasEntries: true))
        DayProgressRingGlyph(progress: DayProgress(id: .now, date: .now, caloriesConsumed: 2400, caloriesTarget: 2000, proteinConsumed: 140, proteinTarget: 130, hasEntries: true))
        DayProgressRingGlyph(progress: DayProgress(id: .now, date: .now, caloriesConsumed: 0, caloriesTarget: 2000, proteinConsumed: 0, proteinTarget: 130, hasEntries: false))
    }
    .padding()
}
