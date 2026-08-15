import Testing
import CoreGraphics
@testable import MealTracker

struct NutritionLabelOCRServiceTests {
    private typealias Fragment = NutritionLabelOCRService.Fragment

    @Test func mergesWrappedEnergyLineWhenLabelColumnIsPresent() {
        // "Energy" row wraps onto two visual lines (kJ above kcal), but Fat and Protein below it
        // are single-line rows with a clear label at the left margin — enough of a margin signal
        // to trust merging the wrapped line into the row above.
        let fragments: [Fragment] = [
            Fragment(text: "Energy", minX: 0.05, midY: 0.90, height: 0.05),
            Fragment(text: "1549kJ", minX: 0.35, midY: 0.90, height: 0.05),
            Fragment(text: "366kcal", minX: 0.35, midY: 0.84, height: 0.05),
            Fragment(text: "Fat", minX: 0.05, midY: 0.75, height: 0.05),
            Fragment(text: "2.2g", minX: 0.35, midY: 0.75, height: 0.05),
            Fragment(text: "Protein", minX: 0.05, midY: 0.65, height: 0.05),
            Fragment(text: "9.7g", minX: 0.35, midY: 0.65, height: 0.05)
        ]

        let result = NutritionLabelOCRService.assembleRows(from: fragments)
        let rows = result.components(separatedBy: "\n")

        #expect(rows.count == 3)
        #expect(rows[0] == "Energy | 1549kJ | 366kcal")
        #expect(rows[1] == "Fat | 2.2g")
        #expect(rows[2] == "Protein | 9.7g")
    }

    @Test func doesNotMergeWhenNoLineLooksLikeARowLabel() {
        // Simulates the label column being cropped out of frame: every remaining line starts at
        // wildly different, inconsistent x positions with nothing resembling a shared left
        // margin — merging under that condition would collapse unrelated rows together instead
        // of just folding genuine wrapped continuation lines.
        let fragments: [Fragment] = [
            Fragment(text: "1549kJ", minX: 0.40, midY: 0.90, height: 0.05),
            Fragment(text: "366kcal", minX: 0.10, midY: 0.84, height: 0.05),
            Fragment(text: "2.2g", minX: 0.55, midY: 0.75, height: 0.05),
            Fragment(text: "9.7g", minX: 0.02, midY: 0.65, height: 0.05)
        ]

        let result = NutritionLabelOCRService.assembleRows(from: fragments)
        let rows = result.components(separatedBy: "\n")

        #expect(rows.count == 4)
    }

    @Test func returnsEmptyStringForNoFragments() {
        #expect(NutritionLabelOCRService.assembleRows(from: []) == "")
    }
}
