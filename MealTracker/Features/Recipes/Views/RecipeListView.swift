import SwiftUI
import SwiftData

/// Presented from `AddFoodView`'s "Recipes" action. Lists this profile's saved recipes for a
/// fast re-log, with a way to build a new one — mirrors `AddFoodView`'s own "recent items / build
/// something new" shape.
struct RecipeListView: View {
    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var onLogged: () -> Void

    @Query private var allRecipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var editingRecipe: Recipe?
    @State private var path = NavigationPath()

    init(mealSlot: MealSlotConfig, date: Date = Date(), onLogged: @escaping () -> Void) {
        self.mealSlot = mealSlot
        self.date = date
        self.onLogged = onLogged
        let profileID = mealSlot.profile?.id
        _allRecipes = Query(filter: #Predicate<Recipe> { $0.profile?.id == profileID }, sort: \Recipe.createdAt, order: .reverse)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    Button {
                        createRecipe()
                    } label: {
                        Label("New Recipe", systemImage: "plus.circle.fill")
                            .font(.manrope(14, weight: .semibold))
                            .foregroundStyle(Color.dashboardCard)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.dashboardAccent, in: RoundedRectangle(cornerRadius: 16))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if allRecipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes Yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Build a recipe from ingredients you already log, then add it here in one tap.")
                        )
                        .padding(.top, 20)
                    } else {
                        FoodResultsCardView(title: "Your Recipes", items: allRecipes) { recipe in
                            Button {
                                // Snapshotting into a FoodItem here (a genuine mutation — it
                                // inserts and saves) must only ever happen from a real tap, never
                                // as part of building this row: this same view's `allRecipes` is
                                // a live `@Query`, so a mutation performed while constructing the
                                // row would invalidate that query, forcing a re-render that
                                // rebuilds the row and mutates again — an infinite loop. Pushing a
                                // value onto `path` (rather than an inline `NavigationLink`
                                // destination closure, which SwiftUI evaluates eagerly for every
                                // row in a `ForEach`) is what keeps this to a single evaluation,
                                // on tap.
                                path.append(loggableFoodItem(for: recipe))
                            } label: {
                                RecipeRowView(
                                    recipe: recipe,
                                    onEdit: { editingRecipe = recipe },
                                    onDelete: { deleteRecipe(recipe) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.dashboardCanvas)
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationDestination(for: FoodItem.self) { foodItem in
                ProductLookupResultView(foodItem: foodItem, mealSlot: mealSlot, date: date, onLogged: onLogged)
            }
            .sheet(item: $editingRecipe) { recipe in
                RecipeEditorView(recipe: recipe)
            }
        }
    }

    private func createRecipe() {
        let recipe = Recipe(name: "", profile: mealSlot.profile)
        modelContext.insert(recipe)
        editingRecipe = recipe
    }

    /// `ProductLookupResultView` expects a concrete, loggable `FoodItem` — see `RecipeMapper` for
    /// why this snapshots fresh nutrition rather than referencing the recipe directly.
    private func loggableFoodItem(for recipe: Recipe) -> FoodItem {
        let foodItem = RecipeMapper.makeFoodItem(from: recipe)
        modelContext.insert(foodItem)
        try? modelContext.save()
        return foodItem
    }

    private func deleteRecipe(_ recipe: Recipe) {
        modelContext.delete(recipe)
        try? modelContext.save()
    }
}

private struct RecipeRowView: View {
    let recipe: Recipe
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.dashboardBarTrack)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(recipe.name)
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text("\(Int(recipe.caloriesPerServing)) cal · 1 serving")
                    .font(.manrope(11, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.dashboardAccent)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
