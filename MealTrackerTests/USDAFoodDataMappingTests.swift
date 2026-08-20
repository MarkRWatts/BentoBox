import Testing
import Foundation
@testable import MealTracker

struct USDAFoodDataMappingTests {
    @Test func prefersLabelNutrientsWhenPresent() throws {
        let json = """
        {
          "fdcId": 1,
          "description": "Cheddar Cheese",
          "brandOwner": "Acme Dairy",
          "servingSize": 28,
          "servingSizeUnit": "g",
          "labelNutrients": {
            "calories": { "value": 110 },
            "fat": { "value": 9 },
            "saturatedFat": { "value": 6 },
            "carbohydrates": { "value": 1 },
            "fiber": { "value": 0 },
            "sugars": { "value": 0 },
            "protein": { "value": 7 },
            "sodium": { "value": 180 }
          },
          "foodNutrients": []
        }
        """
        let food = try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8))
        let foodItem = USDAFoodDataMapper.makeFoodItem(from: food)

        #expect(foodItem.name == "Cheddar Cheese")
        #expect(foodItem.brand == "Acme Dairy")
        #expect(foodItem.barcode == nil)
        #expect(foodItem.servingSizeDescription == "28 g")
        #expect(foodItem.servingSizeGrams == 28)
        #expect(foodItem.caloriesPerServing == 110)
        #expect(foodItem.proteinGramsPerServing == 7)
        #expect(foodItem.sodiumMgPerServing == 180)
        #expect(foodItem.source == .usda)
    }

    @Test func fallsBackToPer100gScaledByServingSizeWhenNoLabelNutrients() throws {
        let json = """
        {
          "fdcId": 2,
          "description": "Apples, raw",
          "servingSize": 150,
          "servingSizeUnit": "g",
          "foodNutrients": [
            { "nutrientName": "Energy", "value": 52 },
            { "nutrientName": "Protein", "value": 0.3 },
            { "nutrientName": "Carbohydrate, by difference", "value": 14 },
            { "nutrientName": "Total lipid (fat)", "value": 0.2 }
          ]
        }
        """
        let food = try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8))
        let foodItem = USDAFoodDataMapper.makeFoodItem(from: food)

        #expect(foodItem.servingSizeDescription == "150 g")
        #expect(foodItem.caloriesPerServing == 78) // 52 * 1.5
        #expect(abs(foodItem.proteinGramsPerServing - 0.45) < 0.0001) // 0.3 * 1.5
    }

    @Test func fallsBackToPer100gWhenNoServingSizeGiven() throws {
        let json = """
        {
          "fdcId": 3,
          "description": "Rice, white",
          "foodNutrients": [
            { "nutrientName": "Energy", "value": 130 }
          ]
        }
        """
        let food = try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8))
        let foodItem = USDAFoodDataMapper.makeFoodItem(from: food)

        #expect(foodItem.servingSizeDescription == "100 g")
        #expect(foodItem.servingSizeGrams == 100)
        #expect(foodItem.caloriesPerServing == 130)
    }

    @Test func fallsBackToUnknownFoodWhenDescriptionIsBlank() throws {
        let json = """
        { "fdcId": 4, "description": "   " }
        """
        let food = try JSONDecoder().decode(USDAFood.self, from: Data(json.utf8))
        let foodItem = USDAFoodDataMapper.makeFoodItem(from: food)
        #expect(foodItem.name == "Unknown Food")
    }

    @Test func isUsableSearchResultRequiresANonBlankDescription() throws {
        let usable = try JSONDecoder().decode(USDAFood.self, from: Data("""
        { "fdcId": 1, "description": "Milk" }
        """.utf8))
        #expect(usable.isUsableSearchResult)

        let blank = try JSONDecoder().decode(USDAFood.self, from: Data("""
        { "fdcId": 2, "description": "" }
        """.utf8))
        #expect(!blank.isUsableSearchResult)
    }
}
