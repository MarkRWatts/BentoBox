import SwiftUI
import SwiftData

/// Builds or edits a `Recipe`. The recipe passed in is already inserted into the model context by
/// the caller (`RecipeListView.createRecipe`) — Cancel here deletes it again if it was never
/// actually named, so backing out of a fresh "New Recipe" leaves nothing behind.
struct RecipeEditorView: View {
    @Bindable var recipe: Recipe

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isPresentingIngredientPicker = false
    @State private var servingsText: String

    init(recipe: Recipe) {
        self.recipe = recipe
        _servingsText = State(initialValue: Self.formatted(recipe.servings))
    }

    private var isValid: Bool {
        !recipe.name.trimmingCharacters(in: .whitespaces).isEmpty && !recipe.ingredients.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Name", text: $recipe.name)
                    HStack {
                        Text("Servings")
                        Spacer()
                        TextField("Servings", text: $servingsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                            .onChange(of: servingsText) { _, newValue in
                                if let value = Double(newValue), value > 0 {
                                    recipe.servings = value
                                }
                            }
                    }
                }

                Section("Ingredients") {
                    if recipe.ingredients.isEmpty {
                        Text("No ingredients yet.")
                            .foregroundStyle(Color.dashboardInkSecondary)
                    }
                    ForEach(recipe.ingredients) { ingredient in
                        IngredientRowView(ingredient: ingredient)
                    }
                    .onDelete(perform: deleteIngredients)
                    Button {
                        isPresentingIngredientPicker = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                }

                if !recipe.ingredients.isEmpty {
                    Section("Nutrition per Serving") {
                        LabeledContent("Calories", value: "\(Int(recipe.caloriesPerServing))")
                        LabeledContent("Protein", value: "\(Int(recipe.proteinGramsPerServing)) g")
                        LabeledContent("Carbs", value: "\(Int(recipe.carbGramsPerServing)) g")
                        LabeledContent("Fat", value: "\(Int(recipe.fatGramsPerServing)) g")
                    }
                }
            }
            .navigationTitle(recipe.name.isEmpty ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $isPresentingIngredientPicker) {
                IngredientPickerView(recipe: recipe)
            }
        }
    }

    private func deleteIngredients(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(recipe.ingredients[index])
        }
    }

    private func cancel() {
        if recipe.name.trimmingCharacters(in: .whitespaces).isEmpty {
            modelContext.delete(recipe)
        }
        dismiss()
    }

    private func save() {
        recipe.name = recipe.name.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
        dismiss()
    }

    private static func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

private struct IngredientRowView: View {
    @Bindable var ingredient: RecipeIngredient

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ingredient.foodItem?.name ?? "Unknown Food")
                    .font(.body)
                Spacer()
                Text("\(Int(ingredient.calories)) cal")
                    .foregroundStyle(.secondary)
            }
            PortionQuantityField(quantity: $ingredient.quantity, servingSizeGrams: ingredient.foodItem?.servingSizeGrams)
        }
    }
}
