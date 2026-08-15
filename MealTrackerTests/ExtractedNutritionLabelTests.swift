import Testing
@testable import MealTracker

struct NutritionLabelExtractorParsingTests {
    @Test func dataColumnHeadersDropsLabelColumnAndReferenceIntake() {
        let headerRow = "Typical Values | Per 100g | Per 40g serving | % RI"
        let columns = NutritionLabelExtractor.dataColumnHeaders(from: headerRow)
        #expect(columns == ["Per 100g", "Per 40g serving"])
    }

    @Test func dataColumnHeadersHandlesSingleUSColumn() {
        let headerRow = "Amount Per Serving | 1 cup (240g)"
        let columns = NutritionLabelExtractor.dataColumnHeaders(from: headerRow)
        #expect(columns == ["1 cup (240g)"])
    }

    @Test func preferredColumnIndexPicksServingOverPer100RegardlessOfOrder() {
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: ["Per 100g", "Per 40g serving"]) == 1)
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: ["Per 40g serving", "Per 100g"]) == 0)
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: ["1 cup (240g)"]) == 0)
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: []) == 0)
    }

    @Test func numbersExtractsOnlyKcalIgnoringKJ() {
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*kcal"#, in: "1549kJ | 366kcal | 620kJ | 146kcal") == [366, 146])
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*kcal"#, in: "764kJ/181kcal") == [181])
    }

    @Test func numbersExtractsGramValuesIgnoringPercentages() {
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*g"#, in: "Fat | 2.2g | 0.9g | 10%") == [2.2, 0.9])
    }

    @Test func resolveEndToEndPicksServingColumnAcrossAllFields() {
        let selection = NutritionLabelRowSelection(
            productName: "Shreddies",
            headerRow: "Typical Values | Per 100g | Per 40g serving",
            energyRow: "Energy | 1549kJ | 366kcal | 620kJ | 146kcal",
            fatRow: "Fat | 2.2g | 0.9g",
            carbRow: "Carbohydrate | 71.4g | 28.6g",
            proteinRow: "Protein | 9.7g | 3.9g",
            confidence: 0.9
        )

        let result = NutritionLabelExtractor.resolve(selection)
        #expect(result.servingSizeDescription == "Per 40g serving")
        #expect(result.calories == 146)
        #expect(result.fatGrams == 0.9)
        #expect(result.carbGrams == 28.6)
        #expect(result.proteinGrams == 3.9)
    }

    @Test func resolveHandlesSingleColumnUSLabel() {
        let selection = NutritionLabelRowSelection(
            productName: "Peanut Butter",
            headerRow: "Amount Per Serving | 1 cup (240g)",
            energyRow: "Calories | 190kcal",
            fatRow: "Total Fat | 16g",
            carbRow: "Total Carbohydrate | 6g",
            proteinRow: "Protein | 7g",
            confidence: 0.9
        )

        let result = NutritionLabelExtractor.resolve(selection)
        #expect(result.servingSizeDescription == "1 cup (240g)")
        #expect(result.calories == 190)
        #expect(result.fatGrams == 16)
    }
}
