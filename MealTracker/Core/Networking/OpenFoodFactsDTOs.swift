import Foundation

struct OFFProductResponse: Decodable {
    let status: Int
    let product: OFFProduct?
}

/// Also doubles as a search result row — `code` isn't needed for the single-barcode lookup
/// (the barcode used to fetch is already known), but search returns many products at once and
/// each needs its own barcode for caching/logging.
struct OFFProduct: Decodable {
    let code: String?
    let productName: String?
    let brands: String?
    let servingSize: String?
    let nutriments: OFFNutriments?
    /// Front-of-pack thumbnail (~100px), when the contributor uploaded one — used for list rows.
    let imageThumbURL: String?
    /// Front-of-pack photo at full display size (~400px) — used where there's room to show it
    /// larger, e.g. the entry edit screen, where the thumbnail would look blurry blown up.
    let imageFrontURL: String?

    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case brands
        case servingSize = "serving_size"
        case nutriments
        case imageThumbURL = "image_front_thumb_url"
        case imageFrontURL = "image_front_url"
    }

    /// Excludes results with no barcode (can't be cached/logged) or no calorie figure at all —
    /// Open Food Facts' crowd-sourced catalog has plenty of near-empty entries (a name and
    /// nothing else) that are just noise in a search result list otherwise.
    var isUsableSearchResult: Bool {
        guard let code, !code.isEmpty else { return false }
        guard let nutriments else { return false }
        return nutriments.energyKcalServing != nil || nutriments.energyKcal100g != nil
    }
}

/// Response shape for the text-search endpoint — a page of matching products.
struct OFFSearchResponse: Decodable {
    let products: [OFFProduct]
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
