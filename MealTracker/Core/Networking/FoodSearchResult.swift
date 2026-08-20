import Foundation
import SwiftData

/// A search result from either backing source — kept source-tagged (rather than mapped into a
/// shared shape immediately) so provenance survives into `FoodItem.source` when one is picked,
/// and so each source's own preview/lookup logic stays in one place. Shared between `AddFoodView`
/// (logging straight to a meal) and `IngredientPickerView` (picking a recipe ingredient), which
/// otherwise need identical search-result handling.
enum FoodSearchResult {
    case openFoodFacts(OFFProduct)
    case usda(USDAFood)

    /// Reuses each source's mapper purely to derive display figures — nothing here is inserted
    /// into the model context, that only happens if this result is actually picked
    /// (`resolveFoodItem`).
    var preview: FoodItem {
        switch self {
        case .openFoodFacts(let product):
            return OpenFoodFactsMapper.makeFoodItem(from: product, barcode: product.code ?? "")
        case .usda(let food):
            return USDAFoodDataMapper.makeFoodItem(from: food)
        }
    }

    /// USDA's search response carries no product imagery, so this is nil for `.usda` results —
    /// `FoodThumbnailView` already falls back to a placeholder for any nil URL.
    var thumbnailURLString: String? {
        if case .openFoodFacts(let product) = self { return product.imageThumbURL }
        return nil
    }

    /// Reuses a cached FoodItem for this barcode if one already exists (e.g. from a previous
    /// barcode scan) rather than inserting a duplicate — mirrors `BarcodeScanViewModel`'s
    /// cache-check. USDA results carry no barcode at all, so they always insert fresh, the same
    /// as a manual or label-scanned entry.
    func resolveFoodItem(context: ModelContext) -> FoodItem {
        switch self {
        case .openFoodFacts(let product):
            guard let barcode = product.code, !barcode.isEmpty else {
                return OpenFoodFactsMapper.makeFoodItem(from: product, barcode: UUID().uuidString)
            }
            let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.barcode == barcode })
            if let cached = try? context.fetch(descriptor).first {
                return cached
            }
            let foodItem = OpenFoodFactsMapper.makeFoodItem(from: product, barcode: barcode)
            context.insert(foodItem)
            try? context.save()
            return foodItem
        case .usda(let food):
            let foodItem = USDAFoodDataMapper.makeFoodItem(from: food)
            context.insert(foodItem)
            try? context.save()
            return foodItem
        }
    }
}
