import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class FoodLoggingViewModel {
    var name: String = ""
    var brand: String = ""
    var servingSizeDescription: String = "1 serving"
    var calories: Double = 0
    var proteinGrams: Double = 0
    var carbGrams: Double = 0
    var fatGrams: Double = 0
    var saturatedFatGrams: Double = 0
    var fiberGrams: Double = 0
    var sugarGrams: Double = 0
    var sodiumMg: Double = 0
    var quantity: Double = 1
    /// Set when this entry originates from a barcode scan that had no Open Food Facts match,
    /// so the manually-entered nutrition still gets cached against that barcode for next time.
    var barcode: String?
    /// .manual unless this entry originated from label-scan extraction.
    var source: FoodSource = .manual

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && calories >= 0
    }

    /// Live-derived from the free-text serving field — typing e.g. "30g" here activates
    /// gram-based quantity entry the same way an Open Food Facts item with a parseable label
    /// serving size does, with no separate state to keep in sync.
    var servingSizeGrams: Double? {
        OpenFoodFactsMapper.parseExactGrams(from: servingSizeDescription)
    }

    func saveEntry(mealSlot: MealSlotConfig, date: Date = Date(), context: ModelContext) {
        let foodItem = FoodItem(
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.isEmpty ? nil : brand,
            barcode: barcode,
            servingSizeDescription: servingSizeDescription,
            servingSizeGrams: servingSizeGrams,
            caloriesPerServing: calories,
            proteinGramsPerServing: proteinGrams,
            carbGramsPerServing: carbGrams,
            fatGramsPerServing: fatGrams,
            saturatedFatGramsPerServing: saturatedFatGrams,
            fiberGramsPerServing: fiberGrams,
            sugarGramsPerServing: sugarGrams,
            sodiumMgPerServing: sodiumMg,
            source: source
        )
        context.insert(foodItem)

        let entry = LoggedEntry(
            date: date,
            quantity: quantity,
            mealSlotNameSnapshot: mealSlot.name,
            foodItem: foodItem,
            mealSlot: mealSlot
        )
        context.insert(entry)
        try? context.save()
    }
}
