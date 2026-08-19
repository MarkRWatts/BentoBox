import SwiftUI

struct MealSlotRowView: View {
    let mealSlot: MealSlotConfig
    let entries: [LoggedEntry]

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// Best-effort icon/color match on the slot's name (works for the default seeded slots),
    /// falling back to a generic meal/snack look for anything the user renamed or added. Uses
    /// SF Symbols' outline variants rather than `.fill` — paired with a soft tinted background
    /// instead of a solid gradient block, this reads as a lighter, more line-art badge instead
    /// of a colored icon block.
    private var iconStyle: (symbol: String, color: Color) {
        switch mealSlot.name.lowercased() {
        case let name where name.contains("breakfast"): ("sun.horizon", .brandProtein)
        case let name where name.contains("lunch"): ("sun.max", .brandCarbs)
        case let name where name.contains("dinner"): ("moon.stars", .brandFat)
        // `.brandForest` rather than `.accentColor` — the accent color asset brightens
        // considerably in dark mode, which would leave this badge too washed-out to read.
        default: (mealSlot.slotType == .meal ? "fork.knife" : "leaf", .brandForest)
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: iconStyle.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconStyle.color)
                .frame(width: 44, height: 44)
                .background(iconStyle.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(iconStyle.color.opacity(0.35), lineWidth: 1.25))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(mealSlot.name)
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text(entries.isEmpty ? "No entries" : "\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.manrope(11.5, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            Spacer()
            Text("\(Int(totalCalories))")
                .font(.archivo(20, weight: .semibold))
                .foregroundStyle(Color.dashboardInk)
        }
        .padding(.vertical, 6)
        // Used outside `List` now (see `LoggedMealsCardView`), which no longer gives the
        // enclosing `NavigationLink` a full-row hit target for free — without this, tapping the
        // gaps between the icon/text/number (i.e. most of the row) would do nothing.
        .contentShape(Rectangle())
    }
}
