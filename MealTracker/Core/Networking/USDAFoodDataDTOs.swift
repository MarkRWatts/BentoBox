import Foundation

/// USDA FoodData Central's `/v1/foods/search` response shape. Field names already match the
/// API's own JSON keys, so no `CodingKeys` are needed anywhere in this file.
struct USDASearchResponse: Decodable {
    let foods: [USDAFood]
}

struct USDAFood: Decodable {
    let fdcId: Int
    let description: String
    let brandOwner: String?
    /// Present for Branded foods (a labeled package), absent for generic Foundation/SR Legacy
    /// entries (e.g. "Apples, raw") — `USDAFoodDataMapper` branches on this the same way
    /// `OpenFoodFactsMapper` branches on OFF's serving-size presence.
    let servingSize: Double?
    let servingSizeUnit: String?
    /// Per-100g figures, present on every food type — the fallback basis when `labelNutrients`
    /// (per-serving, Branded-only) isn't available.
    let foodNutrients: [USDAFoodNutrient]?
    /// Already per-serving when present — preferred over scaling `foodNutrients` for the same
    /// reason `OpenFoodFactsMapper` prefers OFF's own `*_serving` fields over its `*_100g` ones.
    let labelNutrients: USDALabelNutrients?

    var isUsableSearchResult: Bool {
        !description.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

struct USDAFoodNutrient: Decodable {
    let nutrientName: String?
    let value: Double?
}

struct USDALabelNutrients: Decodable {
    let calories: USDALabelValue?
    let fat: USDALabelValue?
    let saturatedFat: USDALabelValue?
    let carbohydrates: USDALabelValue?
    let fiber: USDALabelValue?
    let sugars: USDALabelValue?
    let protein: USDALabelValue?
    let sodium: USDALabelValue?
}

struct USDALabelValue: Decodable {
    let value: Double?
}
