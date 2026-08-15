import Foundation
import FoundationModels

/// Real-device testing showed the model can correctly transcribe numbers off a label, but can't
/// reliably apply a *judgment call* ("always prefer the per-serving column") consistently across
/// every field in one pass — different fields in the same extraction ended up pulled from
/// different columns. So the model is only asked to transcribe both columns verbatim (a
/// mechanical task it does reliably); which column is "the serving one" is then decided
/// deterministically in Swift, in `resolved*` below.
@Generable
struct ExtractedNutritionLabel {
    @Guide(description: "Product or food name if visible on the label, else empty string")
    var productName: String

    @Guide(description: "The header text of the first (left-most) nutrition value column, e.g. 'Per 100g' or '1 cup (240g)' on a single-column label")
    var firstColumnHeader: String

    @Guide(description: "The header text of the second nutrition value column, e.g. 'Per 40g serving'. Empty string if the label has only one value column")
    var secondColumnHeader: String

    @Guide(description: "Energy in kcal (Calories, not kJ) from the first column")
    var firstColumnCalories: Double
    @Guide(description: "Energy in kcal (Calories, not kJ) from the second column, 0 if there is no second column")
    var secondColumnCalories: Double

    @Guide(description: "Grams of fat from the first column's 'Fat' row — never its 'of which saturates' sub-row")
    var firstColumnFatGrams: Double
    @Guide(description: "Grams of fat from the second column's 'Fat' row, 0 if no second column — never its 'of which saturates' sub-row")
    var secondColumnFatGrams: Double

    @Guide(description: "Grams of carbohydrate from the first column's 'Carbohydrate' row — never its 'of which sugars' sub-row")
    var firstColumnCarbGrams: Double
    @Guide(description: "Grams of carbohydrate from the second column's 'Carbohydrate' row, 0 if no second column — never its 'of which sugars' sub-row")
    var secondColumnCarbGrams: Double

    @Guide(description: "Grams of protein from the first column")
    var firstColumnProteinGrams: Double
    @Guide(description: "Grams of protein from the second column, 0 if no second column")
    var secondColumnProteinGrams: Double

    @Guide(description: "Confidence from 0 to 1 that the extracted values are complete and correct")
    var confidence: Double
}

extension ExtractedNutritionLabel {
    private static func looksLikePer100(_ header: String) -> Bool {
        let normalized = header.lowercased()
        return normalized.contains("100g") || normalized.contains("100 g")
            || normalized.contains("100ml") || normalized.contains("100 ml")
    }

    /// The second column is "the serving one" only when the first column is a generic per-100g/
    /// per-100ml figure and a distinct, non-per-100 second column exists — this stays correct
    /// however the label orders its columns, since it keys off header text, not position.
    var prefersSecondColumn: Bool {
        let trimmedSecond = secondColumnHeader.trimmingCharacters(in: .whitespaces)
        guard !trimmedSecond.isEmpty else { return false }
        return Self.looksLikePer100(firstColumnHeader) && !Self.looksLikePer100(trimmedSecond)
    }

    var resolvedServingSizeDescription: String {
        let header = (prefersSecondColumn ? secondColumnHeader : firstColumnHeader)
            .trimmingCharacters(in: .whitespaces)
        return header.isEmpty ? "1 serving" : header
    }

    var resolvedCalories: Double { prefersSecondColumn ? secondColumnCalories : firstColumnCalories }
    var resolvedFatGrams: Double { prefersSecondColumn ? secondColumnFatGrams : firstColumnFatGrams }
    var resolvedCarbGrams: Double { prefersSecondColumn ? secondColumnCarbGrams : firstColumnCarbGrams }
    var resolvedProteinGrams: Double { prefersSecondColumn ? secondColumnProteinGrams : firstColumnProteinGrams }
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
            nutrition label. The OCR text is laid out as rows top-to-bottom, with each row's \
            column values separated by " | " in left-to-right order matching the header row.

            Nutrition labels usually have one or two value columns — for example a single \
            US-style "1 cup (240g)" column, or a UK/EU-style "Per 100g" column alongside a \
            "Per 40g serving" column. Transcribe the first (left-most) value column into the \
            "firstColumn..." fields, copying its header text exactly. If a second, distinct value \
            column exists, transcribe it into the "secondColumn..." fields the same way; if there \
            is no second column, leave secondColumnHeader empty and its values at 0. Do not judge \
            which column is more important — just transcribe what each column actually shows.

            If the label has a third "Reference Intake" / "%RI" / "RI*" column, ignore it \
            entirely — it does not describe this food, and must not be treated as the first or \
            second column.

            For every nutrient, match the row by its exact label: "Fat" is a different row from \
            "of which saturates" beneath it, and "Carbohydrate" is a different row from "of which \
            sugars" beneath it. Always use the parent row's own value ("Fat", "Carbohydrate"), \
            never a "of which" sub-row's value, even though the sub-row is usually smaller and \
            listed directly below.

            Energy is often given in both kJ and kcal within the same column, either as two \
            separate values ("1549kJ | 366kcal") or one combined token joined by a slash \
            ("764kJ/181kcal", kJ first then kcal). Report only the kcal figure — kJ is roughly \
            4x the kcal value for the same amount, so a calories figure that looks about 4x too \
            high means the kJ number was used by mistake.

            Only use values explicitly present in the text. If a value is missing, use 0. Do not \
            guess or estimate.
            """)

        let response = try await session.respond(
            to: "OCR text (rows top-to-bottom, columns left-to-right separated by \" | \"):\n\(ocrText)",
            generating: ExtractedNutritionLabel.self
        )
        return response.content
    }
}
