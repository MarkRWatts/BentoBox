import Foundation

struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

struct OFFProduct: Decodable {
    let productName: String?
    let brands: String?
    let servingSize: String?
    let nutriments: OFFNutriments?

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
    }
}

/// Open Food Facts reports most values per 100g, and per-serving values only when the
/// contributor filled them in. OpenFoodFactsMapper prefers the *_serving fields when present.
struct OFFNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?
    let fiber100g: Double?
    let sugars100g: Double?
    /// Grams per 100g, per OFF convention — converted to mg when mapped onto FoodItem.
    let sodium100g: Double?

    let energyKcalServing: Double?
    let proteinsServing: Double?
    let carbohydratesServing: Double?
    let fatServing: Double?
    let fiberServing: Double?
    let sugarsServing: Double?
    let sodiumServing: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
        case fiber100g = "fiber_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case energyKcalServing = "energy-kcal_serving"
        case proteinsServing = "proteins_serving"
        case carbohydratesServing = "carbohydrates_serving"
        case fatServing = "fat_serving"
        case fiberServing = "fiber_serving"
        case sugarsServing = "sugars_serving"
        case sodiumServing = "sodium_serving"
    }
}
