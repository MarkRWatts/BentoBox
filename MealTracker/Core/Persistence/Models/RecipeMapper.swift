import Foundation

enum RecipeMapper {
    /// Snapshots the recipe's *current* per-serving nutrition into a fresh `FoodItem` — the log
    /// entry this becomes must never change retroactively just because the recipe was edited
    /// later (see the note on `Recipe` itself).
    static func makeFoodItem(from recipe: Recipe) -> FoodItem {
        FoodItem(
            name: recipe.name,
            servingSizeDescription: "1 serving",
            caloriesPerServing: recipe.caloriesPerServing,
            proteinGramsPerServing: recipe.proteinGramsPerServing,
            carbGramsPerServing: recipe.carbGramsPerServing,
            fatGramsPerServing: recipe.fatGramsPerServing,
            saturatedFatGramsPerServing: recipe.saturatedFatGramsPerServing,
            fiberGramsPerServing: recipe.fiberGramsPerServing,
            sugarGramsPerServing: recipe.sugarGramsPerServing,
            sodiumMgPerServing: recipe.sodiumMgPerServing,
            source: .recipe
        )
    }
}
