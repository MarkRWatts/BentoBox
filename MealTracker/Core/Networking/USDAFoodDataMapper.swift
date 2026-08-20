import Foundation

enum USDAFoodDataMapper {
    static func makeFoodItem(from food: USDAFood) -> FoodItem {
        let trimmedName = food.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Unknown Food" : trimmedName

        let brand = food.brandOwner?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBrand = (brand?.isEmpty == false) ? brand : nil

        let gramsServing = food.servingSizeUnit?.lowercased() == "g" ? food.servingSize : nil

        let servingDescription: String
        let servingGrams: Double?
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let saturatedFat: Double?
        let fiber: Double?
        let sugar: Double?
        let sodiumMg: Double?

        if let label = food.labelNutrients {
            // Branded food with its own per-serving label figures — most reliable, prefer these.
            servingDescription = gramsServing.map { "\(Int($0)) g" } ?? "1 serving"
            servingGrams = gramsServing
            calories = label.calories?.value ?? 0
            protein = label.protein?.value ?? 0
            carbs = label.carbohydrates?.value ?? 0
            fat = label.fat?.value ?? 0
            saturatedFat = label.saturatedFat?.value
            fiber = label.fiber?.value
            sugar = label.sugars?.value
            sodiumMg = label.sodium?.value
        } else if let grams = gramsServing {
            // Foundation/SR Legacy food with a known serving size — scale the per-100g figures.
            let scale = grams / 100.0
            servingDescription = "\(Int(grams)) g"
            servingGrams = grams
            calories = nutrientValue(in: food, named: "Energy") * scale
            protein = nutrientValue(in: food, named: "Protein") * scale
            carbs = nutrientValue(in: food, named: "Carbohydrate, by difference") * scale
            fat = nutrientValue(in: food, named: "Total lipid (fat)") * scale
            saturatedFat = optionalNutrientValue(in: food, named: "Fatty acids, total saturated").map { $0 * scale }
            fiber = optionalNutrientValue(in: food, named: "Fiber, total dietary").map { $0 * scale }
            sugar = optionalNutrientValue(in: food, named: "Sugars, total including NLEA").map { $0 * scale }
            sodiumMg = optionalNutrientValue(in: food, named: "Sodium, Na").map { $0 * scale }
        } else {
            // No serving size at all — report per 100g as-is, the same last resort
            // `OpenFoodFactsMapper` falls back to.
            servingDescription = "100 g"
            servingGrams = 100
            calories = nutrientValue(in: food, named: "Energy")
            protein = nutrientValue(in: food, named: "Protein")
            carbs = nutrientValue(in: food, named: "Carbohydrate, by difference")
            fat = nutrientValue(in: food, named: "Total lipid (fat)")
            saturatedFat = optionalNutrientValue(in: food, named: "Fatty acids, total saturated")
            fiber = optionalNutrientValue(in: food, named: "Fiber, total dietary")
            sugar = optionalNutrientValue(in: food, named: "Sugars, total including NLEA")
            sodiumMg = optionalNutrientValue(in: food, named: "Sodium, Na")
        }

        return FoodItem(
            name: resolvedName,
            brand: resolvedBrand,
            barcode: nil,
            servingSizeDescription: servingDescription,
            servingSizeGrams: servingGrams,
            caloriesPerServing: calories,
            proteinGramsPerServing: protein,
            carbGramsPerServing: carbs,
            fatGramsPerServing: fat,
            saturatedFatGramsPerServing: saturatedFat,
            fiberGramsPerServing: fiber,
            sugarGramsPerServing: sugar,
            sodiumMgPerServing: sodiumMg,
            source: .usda
        )
    }

    private static func optionalNutrientValue(in food: USDAFood, named name: String) -> Double? {
        food.foodNutrients?.first { $0.nutrientName == name }?.value
    }

    private static func nutrientValue(in food: USDAFood, named name: String) -> Double {
        optionalNutrientValue(in: food, named: name) ?? 0
    }
}
