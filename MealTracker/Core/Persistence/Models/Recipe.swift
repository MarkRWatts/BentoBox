import Foundation
import SwiftData

/// A reusable, named combination of ingredients. Logging a recipe never references it directly —
/// see `RecipeMapper`, which snapshots the recipe's current per-serving nutrition into a fresh
/// `FoodItem` at the moment it's logged, the same "detach a private copy" rule `LoggedEntry`
/// already applies to manual nutrition edits. That keeps a later edit to this recipe (or to one
/// of its ingredients) from silently rewriting the nutrition of a meal logged days ago.
@Model
final class Recipe {
    var id: UUID = UUID()
    var name: String = ""
    var servings: Double = 1
    var createdAt: Date = Date()
    var profile: UserProfile?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    init(name: String, servings: Double = 1, profile: UserProfile? = nil) {
        self.id = UUID()
        self.name = name
        self.servings = servings
        self.createdAt = Date()
        self.profile = profile
    }

    private var resolvedServings: Double { servings > 0 ? servings : 1 }

    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }
    var totalProteinGrams: Double { ingredients.reduce(0) { $0 + $1.proteinGrams } }
    var totalCarbGrams: Double { ingredients.reduce(0) { $0 + $1.carbGrams } }
    var totalFatGrams: Double { ingredients.reduce(0) { $0 + $1.fatGrams } }
    var totalFiberGrams: Double { ingredients.reduce(0) { $0 + $1.fiberGrams } }
    var totalSugarGrams: Double { ingredients.reduce(0) { $0 + $1.sugarGrams } }
    var totalSaturatedFatGrams: Double { ingredients.reduce(0) { $0 + $1.saturatedFatGrams } }
    var totalSodiumMg: Double { ingredients.reduce(0) { $0 + $1.sodiumMg } }

    var caloriesPerServing: Double { totalCalories / resolvedServings }
    var proteinGramsPerServing: Double { totalProteinGrams / resolvedServings }
    var carbGramsPerServing: Double { totalCarbGrams / resolvedServings }
    var fatGramsPerServing: Double { totalFatGrams / resolvedServings }
    var fiberGramsPerServing: Double { totalFiberGrams / resolvedServings }
    var sugarGramsPerServing: Double { totalSugarGrams / resolvedServings }
    var saturatedFatGramsPerServing: Double { totalSaturatedFatGrams / resolvedServings }
    var sodiumMgPerServing: Double { totalSodiumMg / resolvedServings }
}

/// One ingredient line in a `Recipe` — a `FoodItem` plus how many of its servings go into the
/// recipe. Mirrors `LoggedEntry`'s own `foodItem` + `quantity` shape and computed-nutrition
/// properties deliberately, since both represent the same idea: a serving multiplier applied to
/// a `FoodItem`'s per-serving figures.
@Model
final class RecipeIngredient {
    var id: UUID = UUID()
    var quantity: Double = 1
    var foodItem: FoodItem?
    var recipe: Recipe?

    init(quantity: Double = 1, foodItem: FoodItem? = nil, recipe: Recipe? = nil) {
        self.id = UUID()
        self.quantity = quantity
        self.foodItem = foodItem
        self.recipe = recipe
    }

    var calories: Double { (foodItem?.caloriesPerServing ?? 0) * quantity }
    var proteinGrams: Double { (foodItem?.proteinGramsPerServing ?? 0) * quantity }
    var carbGrams: Double { (foodItem?.carbGramsPerServing ?? 0) * quantity }
    var fatGrams: Double { (foodItem?.fatGramsPerServing ?? 0) * quantity }
    var fiberGrams: Double { (foodItem?.fiberGramsPerServing ?? 0) * quantity }
    var sugarGrams: Double { (foodItem?.sugarGramsPerServing ?? 0) * quantity }
    var saturatedFatGrams: Double { (foodItem?.saturatedFatGramsPerServing ?? 0) * quantity }
    var sodiumMg: Double { (foodItem?.sodiumMgPerServing ?? 0) * quantity }
}
