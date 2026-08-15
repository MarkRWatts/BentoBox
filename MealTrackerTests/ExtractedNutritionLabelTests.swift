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

    @Test func preferredColumnIndexIgnoresUnfilteredReferenceIntakeFragment() {
        // Real-device failure: "Reference Intake" split across OCR lines into two separate
        // fragments ("Reference", "Intake") slipped past the combined-phrase RI filter and, since
        // neither fragment looks like "100g", outranked the real serving column by appearing
        // first and matching the old (too-permissive) "isn't per-100g" heuristic.
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: ["Per 100g", "Reference", "Per 40g serving"]) == 2)
        #expect(NutritionLabelExtractor.preferredColumnIndex(in: ["Reference", "Intake", "Per 100g", "Per 40g serving"]) == 3)
    }

    @Test func dataColumnHeadersFiltersSplitReferenceIntakeFragments() {
        let headerRow = "Typical Values | Per 100g | Per 40g serving | Reference | Intake"
        let columns = NutritionLabelExtractor.dataColumnHeaders(from: headerRow)
        #expect(columns == ["Per 100g", "Per 40g serving"])
    }

    @Test func numbersExtractsOnlyKcalIgnoringKJ() {
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*kcal"#, in: "1549kJ | 366kcal | 620kJ | 146kcal") == [366, 146])
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*kcal"#, in: "764kJ/181kcal") == [181])
    }

    @Test func numbersExtractsGramValuesIgnoringPercentages() {
        #expect(NutritionLabelExtractor.numbers(matching: #"([\d.]+)\s*g"#, in: "Fat | 2.2g | 0.9g | 10%") == [2.2, 0.9])
    }

    @Test func sodiumMgConvertsFromSaltGramsUsingStandardFactor() {
        // UK Food Standards Agency / EU convention: sodium(mg) = salt(g) * 400
        #expect(NutritionLabelExtractor.sodiumMg(fromSaltGrams: 0.61) == 244)
        #expect(NutritionLabelExtractor.sodiumMg(fromSaltGrams: 0) == 0)
    }

    @Test func filterToNutritionRelevantLinesDropsIngredientsAndAllergenText() {
        let ocrText = """
        \u{2020} Shreddies is a source of Iron. Iron contributes...
        May contain NUTS and PEANUTS.
        \u{00b9}Rainforest Alliance Certified cocoa. Find out more at ra.c...
        NUTRITION INFORMATION:
        Typical Values | Per 100g | Per 40g serving
        Energy | 1549kJ | 366kcal | 620kJ | 146kcal
        Fat | 2.2g | 0.9g
        Protein | 9.7g | 3.9g
        """
        let filtered = NutritionLabelExtractor.filterToNutritionRelevantLines(ocrText)

        #expect(!filtered.contains("May contain NUTS"))
        #expect(!filtered.contains("Rainforest Alliance"))
        #expect(filtered.contains("Typical Values | Per 100g | Per 40g serving"))
        #expect(filtered.contains("Energy | 1549kJ | 366kcal | 620kJ | 146kcal"))
        #expect(filtered.contains("Protein | 9.7g | 3.9g"))
    }

    @Test func filterToNutritionRelevantLinesFallsBackToFullTextWhenNothingMatches() {
        let ocrText = "Just some unrelated text with no numbers or keywords at all"
        #expect(NutritionLabelExtractor.filterToNutritionRelevantLines(ocrText) == ocrText)
    }

    @Test func resolveEndToEndPicksServingColumnAcrossAllFields() {
        let selection = NutritionLabelRowSelection(
            headerRow: "Typical Values | Per 100g | Per 40g serving",
            energyRow: "Energy | 1549kJ | 366kcal | 620kJ | 146kcal",
            fatRow: "Fat | 2.2g | 0.9g",
            saturatesRow: "of which saturates | 0.7g | 0.3g",
            carbRow: "Carbohydrate | 71.4g | 28.6g",
            sugarsRow: "of which sugars | 22.2g | 8.9g",
            fibreRow: "Fibre | 11.1g | 4.4g",
            proteinRow: "Protein | 9.7g | 3.9g",
            saltRow: "Salt | 0.61g | 0.24g",
            confidence: 0.9
        )

        let result = NutritionLabelExtractor.resolve(selection)
        #expect(result.servingSizeDescription == "Per 40g serving")
        #expect(result.calories == 146)
        #expect(result.fatGrams == 0.9)
        #expect(result.saturatedFatGrams == 0.3)
        #expect(result.carbGrams == 28.6)
        #expect(result.sugarGrams == 8.9)
        #expect(result.fiberGrams == 4.4)
        #expect(result.proteinGrams == 3.9)
        #expect(result.sodiumMg == 96) // 0.24g salt * 400
    }

    @Test func resolveHandlesSingleColumnLabelWithMissingOptionalRows() {
        let selection = NutritionLabelRowSelection(
            headerRow: "Amount Per Serving | 1 cup (240g)",
            energyRow: "Calories | 190kcal",
            fatRow: "Total Fat | 16g",
            saturatesRow: "",
            carbRow: "Total Carbohydrate | 6g",
            sugarsRow: "",
            fibreRow: "",
            proteinRow: "Protein | 7g",
            saltRow: "",
            confidence: 0.9
        )

        let result = NutritionLabelExtractor.resolve(selection)
        #expect(result.servingSizeDescription == "1 cup (240g)")
        #expect(result.calories == 190)
        #expect(result.fatGrams == 16)
        #expect(result.saturatedFatGrams == 0)
        #expect(result.sodiumMg == 0)
    }
}
