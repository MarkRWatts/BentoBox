import SwiftUI
import SwiftData

struct ManualFoodEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = FoodLoggingViewModel()

    let mealSlot: MealSlotConfig
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
                    NutritionField(title: "Fat (g)", value: $viewModel.fatGrams)
                }

                Section("Quantity") {
                    Stepper(value: $viewModel.quantity, in: 0.25...20, step: 0.25) {
                        Text("Servings: \(viewModel.quantity, specifier: "%.2f")")
                    }
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
                        viewModel.saveEntry(mealSlot: mealSlot, context: modelContext)
                        onSaved?()
                        dismiss()
                    }
                    .disabled(!viewModel.isValid)
                }
            }
        }
    }
}
