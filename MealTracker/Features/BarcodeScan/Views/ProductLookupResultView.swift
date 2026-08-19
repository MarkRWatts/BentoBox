import SwiftUI
import SwiftData

struct ProductLookupResultView: View {
    let foodItem: FoodItem
    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var onLogged: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var quantity: Double = 1

    /// Prefers the larger detail-size photo over the list-row thumbnail — nothing shows at all
    /// for manual/label-scanned items with no source photo.
    private var displayImageURLString: String? {
        foodItem.imageDetailURLString ?? foodItem.imageURLString
    }

    var body: some View {
        Form {
            if let displayImageURLString {
                Section {
                    FoodThumbnailView(
                        urlString: displayImageURLString,
                        shape: RoundedRectangle(cornerRadius: 16),
                        placeholderColor: .dashboardBarTrack,
                        size: 120
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }

            Section("Product") {
                LabeledContent("Name", value: foodItem.name)
                if let brand = foodItem.brand {
                    LabeledContent("Brand", value: brand)
                }
                LabeledContent("Serving", value: foodItem.servingSizeDescription)
            }

            Section("Nutrition per Serving") {
                LabeledContent("Calories", value: "\(Int(foodItem.caloriesPerServing))")
                LabeledContent("Protein", value: "\(Int(foodItem.proteinGramsPerServing)) g")
                LabeledContent("Carbs", value: "\(Int(foodItem.carbGramsPerServing)) g")
                LabeledContent("Fat", value: "\(Int(foodItem.fatGramsPerServing)) g")
            }

            Section("Quantity") {
                PortionQuantityField(quantity: $quantity, servingSizeGrams: foodItem.servingSizeGrams)
            }

            Section {
                Button("Add to \(mealSlot.name)") {
                    logEntry()
                }
                .fontWeight(.semibold)
            }
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func logEntry() {
        // Real "now", not `date` — this drives AddFoodView's "Recent" sort order, which should
        // reflect actual usage time even when the entry itself is being backfilled to an
        // earlier day.
        foodItem.lastUsedAt = Date()
        let entry = LoggedEntry(
            date: date,
            quantity: quantity,
            mealSlotNameSnapshot: mealSlot.name,
            foodItem: foodItem,
            mealSlot: mealSlot
        )
        modelContext.insert(entry)
        try? modelContext.save()
        onLogged()
    }
}
