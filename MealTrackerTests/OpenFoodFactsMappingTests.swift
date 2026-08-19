import Testing
import Foundation
@testable import MealTracker

struct OpenFoodFactsMappingTests {
    @Test func mapsProductWithServingFields() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Peanut Butter",
            "brands": "Acme",
            "serving_size": "32 g",
            "nutriments": {
              "energy-kcal_serving": 190,
              "proteins_serving": 7,
              "carbohydrates_serving": 6,
              "fat_serving": 16,
              "fiber_serving": 2,
              "sugars_serving": 3,
              "sodium_serving": 0.15
            }
          }
        }
        """
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(json.utf8))
        let foodItem = try #require(OpenFoodFactsMapper.makeFoodItem(from: response, barcode: "123456"))

        #expect(foodItem.name == "Peanut Butter")
        #expect(foodItem.brand == "Acme")
        #expect(foodItem.barcode == "123456")
        #expect(foodItem.servingSizeDescription == "32 g")
        #expect(foodItem.caloriesPerServing == 190)
        #expect(foodItem.proteinGramsPerServing == 7)
        #expect(foodItem.sodiumMgPerServing == 150)
        #expect(foodItem.source == .openFoodFacts)
    }

    @Test func fallsBackToPer100gScaledByServingSize() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Granola",
            "serving_size": "50 g",
            "nutriments": {
              "energy-kcal_100g": 400,
              "proteins_100g": 10,
              "carbohydrates_100g": 60,
              "fat_100g": 12
            }
          }
        }
        """
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(json.utf8))
        let foodItem = try #require(OpenFoodFactsMapper.makeFoodItem(from: response, barcode: "999"))

        #expect(foodItem.caloriesPerServing == 200) // 400 * 0.5
        #expect(foodItem.proteinGramsPerServing == 5)
        #expect(foodItem.servingSizeGrams == 50)
    }

    @Test func fallsBackToPer100gWhenNoServingSizeGiven() throws {
        let json = """
        {
          "status": 1,
          "product": {
            "product_name": "Rice",
            "nutriments": {
              "energy-kcal_100g": 130,
              "proteins_100g": 2.7
            }
          }
        }
        """
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(json.utf8))
        let foodItem = try #require(OpenFoodFactsMapper.makeFoodItem(from: response, barcode: "111"))

        #expect(foodItem.servingSizeDescription == "100 g")
        #expect(foodItem.caloriesPerServing == 130)
        // The 100g-fallback basis must be reported explicitly, not left nil, or downstream
        // gram-based quantity entry has no basis to convert against.
        #expect(foodItem.servingSizeGrams == 100)
    }

    @Test func returnsNilWhenStatusIsNotFound() throws {
        let json = """
        { "status": 0, "product": null }
        """
        let response = try JSONDecoder().decode(OFFProductResponse.self, from: Data(json.utf8))
        #expect(OpenFoodFactsMapper.makeFoodItem(from: response, barcode: "000") == nil)
    }

    @Test func makesFoodItemDirectlyFromProductForSearchResults() throws {
        // Search results decode straight to OFFProduct (no status/found wrapper), so the shared
        // overload needs to work without going through OFFProductResponse at all.
        let json = """
        {
          "code": "222333",
          "product_name": "Oat Milk",
          "brands": "Acme",
          "nutriments": {
            "energy-kcal_100g": 45,
            "proteins_100g": 1
          }
        }
        """
        let product = try JSONDecoder().decode(OFFProduct.self, from: Data(json.utf8))
        let foodItem = OpenFoodFactsMapper.makeFoodItem(from: product, barcode: "222333")

        #expect(foodItem.name == "Oat Milk")
        #expect(foodItem.barcode == "222333")
        #expect(foodItem.caloriesPerServing == 45)
    }

    @Test func decodesSearchResponseWithMultipleProducts() throws {
        let json = """
        {
          "products": [
            { "code": "111", "product_name": "Product A" },
            { "code": "222", "product_name": "Product B" }
          ]
        }
        """
        let response = try JSONDecoder().decode(OFFSearchResponse.self, from: Data(json.utf8))

        #expect(response.products.count == 2)
        #expect(response.products.map(\.code) == ["111", "222"])
    }

    @Test func isUsableSearchResultRequiresBarcodeAndACalorieFigure() throws {
        let withServingCalories = try JSONDecoder().decode(OFFProduct.self, from: Data("""
        { "code": "123", "product_name": "A", "nutriments": { "energy-kcal_serving": 100 } }
        """.utf8))
        #expect(withServingCalories.isUsableSearchResult)

        let with100gCalories = try JSONDecoder().decode(OFFProduct.self, from: Data("""
        { "code": "123", "product_name": "A", "nutriments": { "energy-kcal_100g": 100 } }
        """.utf8))
        #expect(with100gCalories.isUsableSearchResult)

        let noBarcode = try JSONDecoder().decode(OFFProduct.self, from: Data("""
        { "product_name": "A", "nutriments": { "energy-kcal_100g": 100 } }
        """.utf8))
        #expect(!noBarcode.isUsableSearchResult)

        let noNutrimentsBlock = try JSONDecoder().decode(OFFProduct.self, from: Data("""
        { "code": "123", "product_name": "A" }
        """.utf8))
        #expect(!noNutrimentsBlock.isUsableSearchResult)

        let emptyNutrimentsBlock = try JSONDecoder().decode(OFFProduct.self, from: Data("""
        { "code": "123", "product_name": "A", "nutriments": { "proteins_100g": 5 } }
        """.utf8))
        #expect(!emptyNutrimentsBlock.isUsableSearchResult)
    }

    @Test func parseGramsExtractsLeadingNumber() {
        #expect(OpenFoodFactsMapper.parseGrams(from: "30 g") == 30)
        #expect(OpenFoodFactsMapper.parseGrams(from: "1 bar (45.5g)") == 1) // takes the leading number, not the parenthetical
        #expect(OpenFoodFactsMapper.parseGrams(from: "45.5g") == 45.5)
        #expect(OpenFoodFactsMapper.parseGrams(from: nil) == nil)
    }

    @Test func parseExactGramsRequiresTheWholeStringToBeAGramFigure() {
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "30 g") == 30)
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "245g") == 245)
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "100 grams") == 100)
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "45.5G") == 45.5) // case-insensitive
        // A leading digit isn't reliably grams in free-form user text — unlike `parseGrams`,
        // this must not misread these as gram figures.
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "1 serving") == nil)
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "2 slices") == nil)
        #expect(OpenFoodFactsMapper.parseExactGrams(from: "1 bar (45.5g)") == nil) // parenthetical, not the whole string
    }
}
