import SwiftUI
import SwiftData

/// Quantity is always edited in place on the existing entry — cheap, no shared-data side
/// effects. Editing nutrition/name instead detaches a *new* FoodItem scoped to just this entry
/// rather than mutating the shared cached one: `LoggedEntry.calories` is computed live as
/// `foodItem.caloriesPerServing * quantity`, so mutating a shared FoodItem in place would
/// silently rewrite calories for every other day that also references it. The detached copy
/// gets `barcode: nil` so it can never collide with a future barcode-cache lookup.
struct EditLoggedEntryView: View {
    let entry: LoggedEntry

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var brand: String
    @State private var servingSizeDescription: String
    @State private var calories: Double
    @State private var proteinGrams: Double
    @State private var carbGrams: Double
    @State private var fatGrams: Double
    @State private var saturatedFatGrams: Double
    @State private var fiberGrams: Double
    @State private var sugarGrams: Double
    @State private var sodiumMg: Double
    @State private var quantity: Double

    init(entry: LoggedEntry) {
        self.entry = entry
        let foodItem = entry.foodItem
        _name = State(initialValue: foodItem?.name ?? "")
        _brand = State(initialValue: foodItem?.brand ?? "")
        _servingSizeDescription = State(initialValue: foodItem?.servingSizeDescription ?? "1 serving")
        _calories = State(initialValue: foodItem?.caloriesPerServing ?? 0)
        _proteinGrams = State(initialValue: foodItem?.proteinGramsPerServing ?? 0)
        _carbGrams = State(initialValue: foodItem?.carbGramsPerServing ?? 0)
        _fatGrams = State(initialValue: foodItem?.fatGramsPerServing ?? 0)
        _saturatedFatGrams = State(initialValue: foodItem?.saturatedFatGramsPerServing ?? 0)
        _fiberGrams = State(initialValue: foodItem?.fiberGramsPerServing ?? 0)
        _sugarGrams = State(initialValue: foodItem?.sugarGramsPerServing ?? 0)
        _sodiumMg = State(initialValue: foodItem?.sodiumMgPerServing ?? 0)
        _quantity = State(initialValue: entry.quantity)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    TextField("Brand (optional)", text: $brand)
                    TextField("Serving Size", text: $servingSizeDescription)
                }

                Section("Nutrition per Serving") {
                    NutritionField(title: "Calories", value: $calories)
                    NutritionField(title: "Protein (g)", value: $proteinGrams)
                    NutritionField(title: "Carbs (g)", value: $carbGrams)
                    NutritionField(title: "Sugar (g)", value: $sugarGrams)
                    NutritionField(title: "Fiber (g)", value: $fiberGrams)
                    NutritionField(title: "Fat (g)", value: $fatGrams)
                    NutritionField(title: "Saturated Fat (g)", value: $saturatedFatGrams)
                    NutritionField(title: "Sodium (mg)", value: $sodiumMg)
                }

                Section("Quantity") {
                    Stepper(value: $quantity, in: 0.25...20, step: 0.25) {
                        Text("Servings: \(quantity, specifier: "%.2f")")
                    }
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        entry.quantity = quantity

        if hasNutritionChanges() {
            let previousFoodItem = entry.foodItem
            let detached = FoodItem(
                name: name.trimmingCharacters(in: .whitespaces),
                brand: brand.isEmpty ? nil : brand,
                barcode: nil,
                servingSizeDescription: servingSizeDescription,
                caloriesPerServing: calories,
                proteinGramsPerServing: proteinGrams,
                carbGramsPerServing: carbGrams,
                fatGramsPerServing: fatGrams,
                saturatedFatGramsPerServing: saturatedFatGrams,
                fiberGramsPerServing: fiberGrams,
                sugarGramsPerServing: sugarGrams,
                sodiumMgPerServing: sodiumMg,
                source: .manual
            )
            modelContext.insert(detached)
            entry.foodItem = detached

            // Clean up the old FoodItem only if it was already a private, single-use copy (no
            // barcode, no other entry referencing it) — never touch a shared barcode-cached item.
            if let previousFoodItem, previousFoodItem.barcode == nil, previousFoodItem.loggedEntries.isEmpty {
                modelContext.delete(previousFoodItem)
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func hasNutritionChanges() -> Bool {
        guard let foodItem = entry.foodItem else { return true }
        return name.trimmingCharacters(in: .whitespaces) != foodItem.name
            || (brand.isEmpty ? nil : brand) != foodItem.brand
            || servingSizeDescription != foodItem.servingSizeDescription
            || calories != foodItem.caloriesPerServing
            || proteinGrams != foodItem.proteinGramsPerServing
            || carbGrams != foodItem.carbGramsPerServing
            || fatGrams != foodItem.fatGramsPerServing
            || saturatedFatGrams != (foodItem.saturatedFatGramsPerServing ?? 0)
            || fiberGrams != (foodItem.fiberGramsPerServing ?? 0)
            || sugarGrams != (foodItem.sugarGramsPerServing ?? 0)
            || sodiumMg != (foodItem.sodiumMgPerServing ?? 0)
    }
}
