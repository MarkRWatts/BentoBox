import Testing
@testable import MealTracker

struct ExtractedNutritionLabelTests {
    @Test func prefersServingColumnWhenFirstColumnIsPer100() {
        let extracted = ExtractedNutritionLabel(
            productName: "Shreddies",
            firstColumnHeader: "Per 100g",
            secondColumnHeader: "Per 40g serving",
            firstColumnCalories: 366, secondColumnCalories: 146,
            firstColumnFatGrams: 2.2, secondColumnFatGrams: 0.9,
            firstColumnCarbGrams: 71.4, secondColumnCarbGrams: 28.6,
            firstColumnProteinGrams: 9.7, secondColumnProteinGrams: 3.9,
            confidence: 0.9
        )

        #expect(extracted.prefersSecondColumn)
        #expect(extracted.resolvedCalories == 146)
        #expect(extracted.resolvedFatGrams == 0.9)
        #expect(extracted.resolvedCarbGrams == 28.6)
        #expect(extracted.resolvedProteinGrams == 3.9)
        #expect(extracted.resolvedServingSizeDescription == "Per 40g serving")
    }

    @Test func usesFirstColumnWhenServingColumnComesFirst() {
        // Column order isn't guaranteed to be [100g, serving] — a label listing the serving
        // column first should still resolve to that column, not flip to per-100g.
        let extracted = ExtractedNutritionLabel(
            productName: "Cereal",
            firstColumnHeader: "Per 40g serving",
            secondColumnHeader: "Per 100g",
            firstColumnCalories: 146, secondColumnCalories: 366,
            firstColumnFatGrams: 0.9, secondColumnFatGrams: 2.2,
            firstColumnCarbGrams: 28.6, secondColumnCarbGrams: 71.4,
            firstColumnProteinGrams: 3.9, secondColumnProteinGrams: 9.7,
            confidence: 0.9
        )

        #expect(!extracted.prefersSecondColumn)
        #expect(extracted.resolvedCalories == 146)
        #expect(extracted.resolvedServingSizeDescription == "Per 40g serving")
    }

    @Test func usesFirstColumnForSingleColumnUSLabel() {
        let extracted = ExtractedNutritionLabel(
            productName: "Peanut Butter",
            firstColumnHeader: "1 cup (240g)",
            secondColumnHeader: "",
            firstColumnCalories: 190, secondColumnCalories: 0,
            firstColumnFatGrams: 16, secondColumnFatGrams: 0,
            firstColumnCarbGrams: 6, secondColumnCarbGrams: 0,
            firstColumnProteinGrams: 7, secondColumnProteinGrams: 0,
            confidence: 0.9
        )

        #expect(!extracted.prefersSecondColumn)
        #expect(extracted.resolvedCalories == 190)
        #expect(extracted.resolvedServingSizeDescription == "1 cup (240g)")
    }

    @Test func fallsBackToGenericServingWhenNoHeaderPresent() {
        let extracted = ExtractedNutritionLabel(
            productName: "",
            firstColumnHeader: "",
            secondColumnHeader: "",
            firstColumnCalories: 0, secondColumnCalories: 0,
            firstColumnFatGrams: 0, secondColumnFatGrams: 0,
            firstColumnCarbGrams: 0, secondColumnCarbGrams: 0,
            firstColumnProteinGrams: 0, secondColumnProteinGrams: 0,
            confidence: 0
        )

        #expect(extracted.resolvedServingSizeDescription == "1 serving")
    }
}
