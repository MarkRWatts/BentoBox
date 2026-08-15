import Foundation
import FoundationModels

@Generable
struct ExtractedNutritionLabel {
    @Guide(description: "Product or food name if visible on the label, else empty string")
    var productName: String

    @Guide(description: "Serving size as written on the label, e.g. '1 cup (240g)' or '40g serving' if the label's per-serving column header gives it that way")
    var servingSizeDescription: String

    @Guide(description: "Calories per serving")
    var calories: Double

    @Guide(description: "Total fat in grams per serving")
    var fatGrams: Double

    @Guide(description: "Total carbohydrates in grams per serving")
    var carbGrams: Double

    @Guide(description: "Protein in grams per serving")
    var proteinGrams: Double

    @Guide(description: "Dietary fiber in grams per serving, 0 if not listed")
    var fiberGrams: Double

    @Guide(description: "Total sugars in grams per serving, 0 if not listed")
    var sugarGrams: Double

    @Guide(description: "Sodium in milligrams per serving, 0 if not listed")
    var sodiumMg: Double

    @Guide(description: "Confidence from 0 to 1 that the extracted values are complete and correct")
    var confidence: Double
}

enum NutritionLabelExtractor {
    enum ExtractionError: Error, LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): return reason
            }
        }
    }

    /// Nil when Apple Intelligence is ready to use; otherwise a user-facing explanation.
    static func availabilityMessage() -> String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return "This device doesn't support Apple Intelligence."
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Turn on Apple Intelligence in Settings to scan nutrition labels."
        case .unavailable(.modelNotReady):
            return "Apple Intelligence is still preparing on this device. Try again shortly."
        case .unavailable:
            return "Apple Intelligence isn't available on this device right now."
        }
    }

    static func extract(from ocrText: String) async throws -> ExtractedNutritionLabel {
        if let message = availabilityMessage() {
            throw ExtractionError.unavailable(message)
        }

        let session = LanguageModelSession(instructions: """
            You extract structured nutrition facts from OCR text taken from a photo of a \
            nutrition label. The label may be a single-column US-style Nutrition Facts panel, \
            or a table with multiple value columns (for example "Per 100g", "Per 40g serving", \
            "Reference Intake"), where each row of the OCR text is one nutrient with its column \
            values separated by " | " in left-to-right order matching the column headers.

            If the table has both a "per 100g" (or "per 100ml") column and a "per serving" \
            column, always use the per-serving column's values, and set the serving size to \
            that column's header (e.g. "40g serving"). Never combine values from different \
            columns or different rows — each number belongs to exactly one nutrient in exactly \
            one column. Only use values explicitly present in the text. If a value is missing, \
            use 0. Do not guess or estimate.
            """)

        let response = try await session.respond(
            to: "OCR text (rows top-to-bottom, columns left-to-right separated by \" | \"):\n\(ocrText)",
            generating: ExtractedNutritionLabel.self
        )
        return response.content
    }
}
