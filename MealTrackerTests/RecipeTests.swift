import Testing
import Foundation
@testable import MealTracker

struct RecipeTests {
    @Test func perServingNutritionDividesTotalsByServings() {
        let recipe = Recipe(name: "Omelette", servings: 2)
        let egg = FoodItem(
            name: "Egg", servingSizeDescription: "1 egg",
            caloriesPerServing: 70, proteinGramsPerServing: 6, carbGramsPerServing: 0, fatGramsPerServing: 5,
            source: .manual
        )
        let cheese = FoodItem(
            name: "Cheese", servingSizeDescription: "30g",
            caloriesPerServing: 100, proteinGramsPerServing: 7, carbGramsPerServing: 1, fatGramsPerServing: 8,
            source: .manual
        )
        recipe.ingredients = [
            RecipeIngredient(quantity: 3, foodItem: egg, recipe: recipe), // 3 eggs
            RecipeIngredient(quantity: 1, foodItem: cheese, recipe: recipe)
        ]

        // total calories = 3*70 + 1*100 = 310, split across 2 servings = 155
        #expect(recipe.totalCalories == 310)
        #expect(recipe.caloriesPerServing == 155)
        #expect(recipe.totalProteinGrams == 25) // 3*6 + 7
        #expect(recipe.proteinGramsPerServing == 12.5)
    }

    @Test func perServingFallsBackToOneServingWhenServingsIsZeroOrNegative() {
        let recipe = Recipe(name: "Bad Servings", servings: 0)
        let food = FoodItem(
            name: "Food", servingSizeDescription: "1",
            caloriesPerServing: 100, proteinGramsPerServing: 0, carbGramsPerServing: 0, fatGramsPerServing: 0,
            source: .manual
        )
        recipe.ingredients = [RecipeIngredient(quantity: 1, foodItem: food, recipe: recipe)]

        // A zero/negative servings count must never divide-by-zero — treated as 1 serving.
        #expect(recipe.caloriesPerServing == 100)
    }
}

struct RecipeMapperTests {
    @Test func snapshotsCurrentPerServingNutritionTaggedAsRecipeSource() {
        let recipe = Recipe(name: "Smoothie", servings: 2)
        let banana = FoodItem(
            name: "Banana", servingSizeDescription: "1",
            caloriesPerServing: 90, proteinGramsPerServing: 1, carbGramsPerServing: 23, fatGramsPerServing: 0,
            source: .manual
        )
        recipe.ingredients = [RecipeIngredient(quantity: 2, foodItem: banana, recipe: recipe)]

        let foodItem = RecipeMapper.makeFoodItem(from: recipe)

        #expect(foodItem.name == "Smoothie")
        #expect(foodItem.source == .recipe)
        #expect(foodItem.caloriesPerServing == 90) // (90 * 2) / 2 servings
        #expect(foodItem.servingSizeDescription == "1 serving")
    }
}
