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
        /// The gram basis 1x `quantity` actually represents — distinct from the raw
        /// `servingGrams` local above, which only reflects whether the *label* serving size was
        /// gram-parseable. The 100g-fallback branch reports a known basis (100g) even though no
        /// label serving size existed to parse.
        let resolvedServingGrams: Double?
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
            resolvedServingGrams = servingGrams
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
            resolvedServingGrams = grams
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
            resolvedServingGrams = 100
            calories = n.energyKcal100g ?? 0
            protein = n.proteins100g ?? 0
            carbs = n.carbohydrates100g ?? 0
            fat = n.fat100g ?? 0
            fiber = n.fiber100g
            sugar = n.sugars100g
            sodiumMg = n.sodium100g.map { $0 * 1000 }
        } else {
            servingDescription = "1 serving"
            resolvedServingGrams = nil
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
            servingSizeGrams: resolvedServingGrams,
            caloriesPerServing: calories,
            proteinGramsPerServing: protein,
            carbGramsPerServing: carbs,
            fatGramsPerServing: fat,
            fiberGramsPerServing: fiber,
            sugarGramsPerServing: sugar,
            sodiumMgPerServing: sodiumMg,
            imageURLString: product.imageThumbURL,
            imageDetailURLString: product.imageFrontURL,
            source: .openFoodFacts
        )
    }

    /// Extracts the leading number from strings like "30 g" or "1 bar (30g)". Intended for Open
    /// Food Facts' own `serving_size` field, which by convention is a gram/ml quantity — a
    /// leading digit reliably means grams there.
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

    /// Stricter than `parseGrams`: only returns a figure when the *entire* trimmed string is a
    /// number followed by a gram unit ("30 g", "245g", "100 grams"). Use this instead of
    /// `parseGrams` against free-form user-typed serving size text — unlike Open Food Facts'
    /// dedicated `serving_size` field, a user's text can start with a digit that isn't grams at
    /// all ("2 slices", "1 serving"), and `parseGrams` would misread that as a gram figure.
    static func parseExactGrams(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        for suffix in ["grams", "gram", "g"] {
            guard trimmed.hasSuffix(suffix) else { continue }
            if let value = Double(trimmed.dropLast(suffix.count).trimmingCharacters(in: .whitespaces)) {
                return value
            }
        }
        return nil
    }
}
