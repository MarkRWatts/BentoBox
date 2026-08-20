import Foundation

/// OFF-first, USDA-fallback search — shared between `AddFoodView` (logging to a meal) and
/// `IngredientPickerView` (picking a recipe ingredient).
struct FoodSearchService {
    private let offClient = OpenFoodFactsClient()
    private let usdaClient = USDAFoodDataClient()

    /// Open Food Facts skews toward packaged/international goods and is tried first since it's
    /// the richer source when it has a match; USDA FoodData Central only gets a turn when OFF
    /// comes back empty or errors, rather than merging both every time.
    func search(query: String, countryName: String? = nil) async throws -> [FoodSearchResult] {
        do {
            let offResults = try await offClient.searchProducts(query: query, countryName: countryName)
            if !offResults.isEmpty {
                return offResults.map { .openFoodFacts($0) }
            }
        } catch {
            // Falls through to the USDA attempt below rather than surfacing this yet — an OFF
            // outage shouldn't block a search USDA can still answer.
        }
        let usdaResults = try await usdaClient.searchFoods(query: query)
        return usdaResults.map { .usda($0) }
    }
}
