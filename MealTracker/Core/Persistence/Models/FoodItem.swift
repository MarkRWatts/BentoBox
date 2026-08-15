import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var brand: String?
    /// Nil for manual/label-scanned items without a barcode. Checked via predicate query on
    /// lookup rather than relying solely on a unique constraint, since barcode is optional.
    var barcode: String?
    var servingSizeDescription: String = ""
    var servingSizeGrams: Double?
    var caloriesPerServing: Double = 0
    var proteinGramsPerServing: Double = 0
    var carbGramsPerServing: Double = 0
    var fatGramsPerServing: Double = 0
    var fiberGramsPerServing: Double?
    var sugarGramsPerServing: Double?
    var sodiumMgPerServing: Double?
    var source: FoodSource = FoodSource.manual
    var createdAt: Date = Date()
    var lastUsedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \LoggedEntry.foodItem)
    var loggedEntries: [LoggedEntry] = []

    init(
        name: String,
        brand: String? = nil,
        barcode: String? = nil,
        servingSizeDescription: String,
        servingSizeGrams: Double? = nil,
        caloriesPerServing: Double,
        proteinGramsPerServing: Double,
        carbGramsPerServing: Double,
        fatGramsPerServing: Double,
        fiberGramsPerServing: Double? = nil,
        sugarGramsPerServing: Double? = nil,
        sodiumMgPerServing: Double? = nil,
        source: FoodSource
    ) {
        self.id = UUID()
        self.name = name
        self.brand = brand
        self.barcode = barcode
        self.servingSizeDescription = servingSizeDescription
        self.servingSizeGrams = servingSizeGrams
        self.caloriesPerServing = caloriesPerServing
        self.proteinGramsPerServing = proteinGramsPerServing
        self.carbGramsPerServing = carbGramsPerServing
        self.fatGramsPerServing = fatGramsPerServing
        self.fiberGramsPerServing = fiberGramsPerServing
        self.sugarGramsPerServing = sugarGramsPerServing
        self.sodiumMgPerServing = sodiumMgPerServing
        self.source = source
        self.createdAt = Date()
        self.lastUsedAt = Date()
    }
}
