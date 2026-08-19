import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = FoodLoggingViewModel()

    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var prefilledBarcode: String?
    var onSaved: (() -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Brand (optional)", text: $viewModel.brand)
                    TextField("Serving Size", text: $viewModel.servingSizeDescription)
                }

                Section("Nutrition per Serving") {
                    NutritionField(title: "Calories", value: $viewModel.calories)
                    NutritionField(title: "Protein (g)", value: $viewModel.proteinGrams)
                    NutritionField(title: "Carbs (g)", value: $viewModel.carbGrams)
                    NutritionField(title: "Sugar (g)", value: $viewModel.sugarGrams)
                    NutritionField(title: "Fiber (g)", value: $viewModel.fiberGrams)
                    NutritionField(title: "Fat (g)", value: $viewModel.fatGrams)
                    NutritionField(title: "Saturated Fat (g)", value: $viewModel.saturatedFatGrams)
                    NutritionField(title: "Sodium (mg)", value: $viewModel.sodiumMg)
                }

                Section("Quantity") {
                    PortionQuantityField(quantity: $viewModel.quantity, servingSizeGrams: viewModel.servingSizeGrams)
                }
            }
            .navigationTitle("Add to \(mealSlot.name)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.barcode = prefilledBarcode
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveEntry(mealSlot: mealSlot, date: date, context: modelContext)
                        onSaved?()
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}
