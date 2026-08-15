import Foundation
import FoundationModels

/// Final, resolved nutrition facts for one serving — never partially filled with the wrong
/// column's numbers, since column selection and numeric parsing both happen in deterministic
/// Swift code before this is constructed (see NutritionLabelExtractor).
struct ExtractedNutritionLabel {
    var productName: String
    var servingSizeDescription: String
    var calories: Double
    var fatGrams: Double
    var carbGrams: Double
    var proteinGrams: Double
    var confidence: Double
}

/// What the model is actually asked to do: point at the right rows, verbatim. Two rounds of
/// real-device testing showed it cannot reliably *transcribe numbers into the right output
/// fields* across a whole table in one pass (values ended up swapped between columns, and even
/// between unrelated nutrients — e.g. Salt's value landing in the Protein field). Copying a
/// short span of text it can already see, unmodified, is a much easier and more reliable task
/// for a small on-device model than re-typing numbers into a battery of separate fields.
@Generable
struct NutritionLabelRowSelection {
    @Guide(description: "Product or food name if visible in the text, else empty string")
    var productName: String

    @Guide(description: "The header row naming the value columns, copied character-for-character exactly as it appears in the OCR text — do not reformat or reorder it")
    var headerRow: String

    @Guide(description: "The row for Energy (kJ/kcal), copied character-for-character exactly as it appears in the OCR text. Empty string if there is no energy row")
    var energyRow: String

    @Guide(description: "The row for total Fat — not the 'of which saturates' sub-row beneath it — copied character-for-character exactly as it appears in the OCR text. Empty string if there is no fat row")
    var fatRow: String

    @Guide(description: "The row for total Carbohydrate — not the 'of which sugars' sub-row beneath it — copied character-for-character exactly as it appears in the OCR text. Empty string if there is no carbohydrate row")
    var carbRow: String

    @Guide(description: "The row for Protein, copied character-for-character exactly as it appears in the OCR text. Empty string if there is no protein row")
    var proteinRow: String

    @Guide(description: "Confidence from 0 to 1 that the rows above were correctly identified")
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
            You are given OCR text from a photo of a nutrition label, laid out as rows \
            top-to-bottom with each row's column values separated by " | " in left-to-right \
            order matching the header row.

            Find these rows and copy each one out character-for-character exactly as it appears \
            in the OCR text — do not reformat, reorder, retype the numbers, or fix anything:
            - The header row that names the value columns (e.g. "Typical Values | Per 100g | \
            Per 40g serving")
            - The Energy row (kJ/kcal)
            - The total Fat row — not its "of which saturates" sub-row
            - The total Carbohydrate row — not its "of which sugars" sub-row
            - The Protein row

            If a label has a third "Reference Intake" / "%RI" / "RI*" column, leave it in place \
            when you copy each row — it will be handled separately, you don't need to remove it.

            If any of these rows isn't present in the text, leave that field as an empty string. \
            Do not invent a row that isn't there, and do not compute or guess any values.
            """)

        let response = try await session.respond(
            to: "OCR text (rows top-to-bottom, columns left-to-right separated by \" | \"):\n\(ocrText)",
            generating: NutritionLabelRowSelection.self
        )
        return Self.resolve(response.content)
    }

    // MARK: - Deterministic resolution

    /// Turns the model's row selection into final values entirely with string parsing — no
    /// numeric transcription by the model is trusted here.
    static func resolve(_ selection: NutritionLabelRowSelection) -> ExtractedNutritionLabel {
        let columns = dataColumnHeaders(from: selection.headerRow)
        let index = preferredColumnIndex(in: columns)

        return ExtractedNutritionLabel(
            productName: selection.productName,
            servingSizeDescription: columns[safe: index] ?? "1 serving",
            calories: numbers(matching: #"([\d.]+)\s*kcal"#, in: selection.energyRow)[safe: index] ?? 0,
            fatGrams: numbers(matching: #"([\d.]+)\s*g"#, in: selection.fatRow)[safe: index] ?? 0,
            carbGrams: numbers(matching: #"([\d.]+)\s*g"#, in: selection.carbRow)[safe: index] ?? 0,
            proteinGrams: numbers(matching: #"([\d.]+)\s*g"#, in: selection.proteinRow)[safe: index] ?? 0,
            confidence: selection.confidence
        )
    }

    /// The value-column headers from a row like "Typical Values | Per 100g | Per 40g serving".
    /// Our OCR reconstruction always orders each row's fragments left-to-right, so the row-label
    /// column ("Typical Values") is reliably the first segment regardless of its exact wording —
    /// safer than matching on keywords like "per", which also appears in label-column headers
    /// such as "Amount Per Serving". Any Reference Intake column is dropped outright.
    static func dataColumnHeaders(from headerRow: String) -> [String] {
        let segments = headerRow
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard segments.count > 1 else { return segments }
        return segments.dropFirst().filter { !looksLikeReferenceIntake($0) }
    }

    /// Prefers a per-serving column over a per-100g/per-100ml one, wherever it falls in the
    /// (already Reference-Intake-filtered) column list — this is correct regardless of which
    /// order the label itself puts the columns in, since it keys off header text, not position.
    static func preferredColumnIndex(in columns: [String]) -> Int {
        guard columns.count > 1 else { return 0 }
        return columns.firstIndex { !looksLikePer100($0) } ?? 0
    }

    private static func looksLikeReferenceIntake(_ header: String) -> Bool {
        let normalized = header.lowercased().replacingOccurrences(of: " ", with: "")
        return normalized.contains("referenceintake") || normalized.contains("%ri") || normalized.contains("ri*")
    }

    private static func looksLikePer100(_ header: String) -> Bool {
        let normalized = header.lowercased()
        return normalized.contains("100g") || normalized.contains("100 g")
            || normalized.contains("100ml") || normalized.contains("100 ml")
    }

    /// Extracts every number immediately followed by `unit` (e.g. "kcal" or "g") from `text`, in
    /// left-to-right order — e.g. matching only "kcal" numbers on "764kJ/181kcal" skips the kJ
    /// figure automatically, without the model ever having to reason about which unit is which.
    static func numbers(matching pattern: String, in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let numberRange = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[numberRange])
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
