import Foundation

enum OpenFoodFactsMapper {
    /// Returns nil when OFF has no product for this barcode (status != 1).
    static func makeFoodItem(from response: OFFProductResponse, barcode: String) -> FoodItem? {
        guard response.status == 1, let product = response.product else { return nil }
        return makeFoodItem(from: product, barcode: barcode)
    }

    /// Shared by the single-barcode lookup and by search results (each search result is a full
    /// `OFFProduct`, just without the "was this barcode found at all" status wrapper).
    static func makeFoodItem(from product: OFFProduct, barcode: String) -> FoodItem {
        let name = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = (name?.isEmpty == false) ? name! : "Unknown Product"

        let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBrand = (brand?.isEmpty == false) ? brand : nil

        let servingGrams = parseGrams(from: product.servingSize)
        let n = product.nutriments

        let servingDescription: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let fiber: Double?
        let sugar: Double?
        let sodiumMg: Double?

        if let n, n.energyKcalServing != nil {
            // Contributor supplied per-serving values directly — most accurate, prefer these.
            servingDescription = product.servingSize ?? "1 serving"
            calories = n.energyKcalServing ?? 0
            protein = n.proteinsServing ?? 0
            carbs = n.carbohydratesServing ?? 0
            fat = n.fatServing ?? 0
            fiber = n.fiberServing
            sugar = n.sugarsServing
            sodiumMg = n.sodiumServing.map { $0 * 1000 }
        } else if let n, let grams = servingGrams {
            // Scale OFF's standard per-100g figures down to the labeled serving size.
            let scale = grams / 100.0
            servingDescription = product.servingSize ?? "\(Int(grams)) g"
            calories = (n.energyKcal100g ?? 0) * scale
            protein = (n.proteins100g ?? 0) * scale
            carbs = (n.carbohydrates100g ?? 0) * scale
            fat = (n.fat100g ?? 0) * scale
            fiber = n.fiber100g.map { $0 * scale }
            sugar = n.sugars100g.map { $0 * scale }
            sodiumMg = n.sodium100g.map { $0 * scale * 1000 }
        } else if let n {
            // No serving size on the label — fall back to reporting per 100g as-is.
            servingDescription = "100 g"
            calories = n.energyKcal100g ?? 0
            protein = n.proteins100g ?? 0
            carbs = n.carbohydrates100g ?? 0
            fat = n.fat100g ?? 0
            fiber = n.fiber100g
            sugar = n.sugars100g
            sodiumMg = n.sodium100g.map { $0 * 1000 }
        } else {
            servingDescription = "1 serving"
            calories = 0
            protein = 0
            carbs = 0
            fat = 0
            fiber = nil
            sugar = nil
            sodiumMg = nil
        }

        return FoodItem(
            name: resolvedName,
            brand: resolvedBrand,
            barcode: barcode,
            servingSizeDescription: servingDescription,
            servingSizeGrams: servingGrams,
            caloriesPerServing: calories,
            proteinGramsPerServing: protein,
            carbGramsPerServing: carbs,
            fatGramsPerServing: fat,
            fiberGramsPerServing: fiber,
            sugarGramsPerServing: sugar,
            sodiumMgPerServing: sodiumMg,
            source: .openFoodFacts
        )
    }

    /// Extracts the leading number from strings like "30 g" or "1 bar (30g)".
    static func parseGrams(from servingSize: String?) -> Double? {
        guard let servingSize else { return nil }
        var numberString = ""
        var foundDigit = false
        for char in servingSize {
            if char.isNumber || (char == "." && foundDigit) {
                numberString.append(char)
                foundDigit = true
            } else if foundDigit {
                break
            }
        }
        return Double(numberString)
    }
}
