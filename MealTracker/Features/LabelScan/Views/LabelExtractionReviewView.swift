import SwiftUI
import SwiftData

/// Extraction output is never saved directly — every field is pre-filled but editable, and
/// only an explicit tap on "Add to <slot>" creates the FoodItem.
struct LabelExtractionReviewView: View {
    let extracted: ExtractedNutritionLabel
    let mealSlot: MealSlotConfig
    var onSaved: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = FoodLoggingViewModel()

    var body: some View {
        Form {
            if extracted.confidence < 0.6 {
                Section {
                    Label(
                        "Some values may be missing or inaccurate — double-check against the label before saving.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }

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

            Section {
                Button("Add to \(mealSlot.name)") {
                    viewModel.saveEntry(mealSlot: mealSlot, context: modelContext)
                    onSaved()
                }
                .fontWeight(.semibold)
                .disabled(!viewModel.isValid)
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.name = extracted.productName
            viewModel.servingSizeDescription = extracted.servingSizeDescription
            viewModel.calories = extracted.calories
            viewModel.proteinGrams = extracted.proteinGrams
            viewModel.carbGrams = extracted.carbGrams
            viewModel.fatGrams = extracted.fatGrams
            viewModel.source = .labelScan
        }
    }
}
