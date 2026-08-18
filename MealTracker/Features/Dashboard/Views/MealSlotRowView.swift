import SwiftUI

struct MealSlotRowView: View {
    let mealSlot: MealSlotConfig
    let entries: [LoggedEntry]

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// Best-effort icon/color match on the slot's name (works for the default seeded slots),
    /// falling back to a generic meal/snack look for anything the user renamed or added.
    private var iconStyle: (symbol: String, color: Color) {
        switch mealSlot.name.lowercased() {
        case let name where name.contains("breakfast"): ("sun.horizon.fill", .brandProtein)
        case let name where name.contains("lunch"): ("sun.max.fill", .brandCarbs)
        case let name where name.contains("dinner"): ("moon.stars.fill", .brandFat)
        // `.brandForest` rather than `.accentColor` — the accent color asset brightens
        // considerably in dark mode (better for text/tints), which leaves the white glyph on
        // top of this icon badge with too little contrast to read clearly.
        default: (mealSlot.slotType == .meal ? "fork.knife" : "leaf.fill", .brandForest)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconStyle.symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(iconStyle.color.gradient, in: RoundedRectangle(cornerRadius: 9))
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(mealSlot.name)
                Text(entries.isEmpty ? "No entries" : "\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(totalCalories)) cal")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
