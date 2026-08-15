import SwiftUI

struct MealSlotRowView: View {
    let mealSlot: MealSlotConfig
    let entries: [LoggedEntry]

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        HStack {
            Image(systemName: mealSlot.slotType == .meal ? "fork.knife" : "leaf")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading) {
                Text(mealSlot.name)
                Text(entries.isEmpty ? "No entries" : "\(entries.count) item\(entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Int(totalCalories)) cal")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
