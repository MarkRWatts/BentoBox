import Foundation
import FoundationModels

/// Final, resolved nutrition facts for one serving — never partially filled with the wrong
/// column's numbers, since column selection and numeric parsing both happen in deterministic
/// Swift code before this is constructed (see NutritionLabelExtractor).
struct ExtractedNutritionLabel {
    var servingSizeDescription: String
    var calories: Double
    var fatGrams: Double
    var saturatedFatGrams: Double
    var carbGrams: Double
    var sugarGrams: Double
    var fiberGrams: Double
    var proteinGrams: Double
    /// Sodium in mg, converted from the label's Salt figure (UK/EU labels report salt, not
    /// sodium — see NutritionLabelExtractor.sodiumMg(fromSaltGrams:)).
    var sodiumMg: Double
    var confidence: Double
}

/// What the model is actually asked to do: point at the right rows, verbatim. Two rounds of
/// real-device testing showed it cannot reliably *transcribe numbers into the right output
/// fields* across a whole table in one pass (values ended up swapped between columns, and even
/// between unrelated nutrients — e.g. Salt's value landing in the Protein field). Copying a
/// short span of text it can already see, unmodified, is a much easier and more reliable task
/// for a small on-device model than re-typing numbers into a battery of separate fields.
///
/// The row set mirrors the standard UK/EU nutrition table (Energy, Fat, of which Saturates,
/// Carbohydrate, of which Sugars, Fibre, Protein, Salt) mandated by EU food labeling
/// regulation — real-world labels have consistently shown exactly this row set.
///
/// There's no productName field — real-device testing showed it just as unreliable as the
/// numbers once were (it picked up an ingredient-certification blurb once), and unlike the
/// numbers a wrong name is easy for the user to just retype, so it's not worth the extra prompt
/// size or another point of failure.
@Generable
struct NutritionLabelRowSelection {
    @Guide(description: "Header row naming the value columns, copied exactly")
    var headerRow: String

    @Guide(description: "Energy (kJ/kcal) row, copied exactly — not the Reference Intake footnote")
    var energyRow: String

    @Guide(description: "Total Fat row, copied exactly — not its 'of which saturates' sub-row")
    var fatRow: String

    @Guide(description: "'Of which saturates' sub-row beneath Fat, copied exactly")
    var saturatesRow: String

    @Guide(description: "Total Carbohydrate row, copied exactly — not its 'of which sugars' sub-row")
    var carbRow: String

    @Guide(description: "'Of which sugars' sub-row beneath Carbohydrate, copied exactly")
    var sugarsRow: String

    @Guide(description: "Fibre row, copied exactly")
    var fibreRow: String

    @Guide(description: "Protein row, copied exactly")
    var proteinRow: String

    @Guide(description: "Salt row from the nutrition table, copied exactly — not an ingredients-list mention of salt")
    var saltRow: String

    @Guide(description: "Confidence 0 to 1 that the rows above are correct")
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

        let relevantText = filterToNutritionRelevantLines(ocrText)

        let session = LanguageModelSession(instructions: """
            OCR text from a nutrition label, rows top-to-bottom, each row's column values \
            separated by " | " left-to-right matching the header row.

            Copy these rows out character-for-character exactly as they appear — no \
            reformatting, reordering, retyping numbers, or fixing anything:
            - Header row naming the value columns (e.g. "Typical Values | Per 100g | Per 40g \
            serving")
            - Energy row (kJ/kcal), from inside the table itself — not a small-print footnote \
            like "Reference intake of an average adult (8400kJ/2000kcal)", which is never this \
            food's own data
            - Fat row, and separately its "of which saturates" sub-row — always two different \
            rows, never copy one into both fields
            - Carbohydrate row, and separately its "of which sugars" sub-row — same rule
            - Fibre row
            - Protein row
            - Salt row from the table itself — not an incidental "salt" mention in an \
            ingredients list

            Leave a third Reference Intake / %RI column in place if present; it's handled \
            separately. Leave a field empty if that row isn't present. Never invent a row or \
            guess a value.
            """)

        let response = try await session.respond(
            to: "OCR text (rows top-to-bottom, columns left-to-right separated by \" | \"):\n\(relevantText)",
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

        func grams(in row: String) -> Double {
            numbers(matching: #"([\d.]+)\s*g"#, in: row)[safe: index] ?? 0
        }

        let saltGrams = numbers(matching: #"([\d.]+)\s*g"#, in: selection.saltRow)[safe: index] ?? 0

        return ExtractedNutritionLabel(
            servingSizeDescription: columns[safe: index] ?? "1 serving",
            calories: numbers(matching: #"([\d.]+)\s*kcal"#, in: selection.energyRow)[safe: index] ?? 0,
            fatGrams: grams(in: selection.fatRow),
            saturatedFatGrams: grams(in: selection.saturatesRow),
            carbGrams: grams(in: selection.carbRow),
            sugarGrams: grams(in: selection.sugarsRow),
            fiberGrams: grams(in: selection.fibreRow),
            proteinGrams: grams(in: selection.proteinRow),
            sodiumMg: sodiumMg(fromSaltGrams: saltGrams),
            confidence: selection.confidence
        )
    }

    /// UK/EU labels report Salt, not Sodium. The standard regulatory conversion (used by the UK
    /// Food Standards Agency and EU food law) is sodium = salt ÷ 2.5 by mass, i.e. for salt in
    /// grams, sodium in mg = salt(g) × 1000 ÷ 2.5 = salt(g) × 400.
    static func sodiumMg(fromSaltGrams saltGrams: Double) -> Double {
        saltGrams * 400
    }

    /// Keeps only OCR lines likely to be part of the nutrition table, dropping ingredients
    /// lists, allergen warnings, certification blurbs, and other label text that just adds noise
    /// (and tokens) without helping. Real-device testing on a busy label hit
    /// GenerationError.exceededContextWindowSize, and separately had the model pick an
    /// ingredient-certification sentence as the "product name" — both point at sending the model
    /// far more text than it needs.
    static func filterToNutritionRelevantLines(_ ocrText: String) -> String {
        let keywords = [
            "energy", "fat", "saturat", "carbohydrate", "sugar", "fibre", "fiber",
            "protein", "salt", "sodium", "typical value", "nutrition", "per 100", "per serving",
            "portion", "kcal", "kj", "reference intake", "%ri", "ri*"
        ]
        let numericPattern = try? NSRegularExpression(pattern: #"\d+(\.\d+)?\s*(g|mg|kcal|kj|%)"#, options: .caseInsensitive)

        let lines = ocrText.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            let lowered = line.lowercased()
            if keywords.contains(where: lowered.contains) { return true }
            guard let numericPattern else { return false }
            let range = NSRange(line.startIndex..., in: line)
            return numericPattern.firstMatch(in: line, range: range) != nil
        }

        // Better to risk a long prompt than to send the model nothing, if filtering somehow
        // stripped every line (e.g. an OCR result with no recognizable label vocabulary at all).
        return filtered.isEmpty ? ocrText : filtered.joined(separator: "\n")
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
    ///
    /// Requires a *positive* signal that a candidate actually looks like a serving description
    /// (contains a digit, or a word like "serving"/"portion"/"pack"), rather than just "isn't
    /// per-100g" — real-device testing showed a stray, unfiltered Reference-Intake fragment (e.g.
    /// "Reference" split from "Intake" across OCR lines) can otherwise outrank the genuine
    /// serving column simply by appearing first and not matching the per-100g pattern either.
    static func preferredColumnIndex(in columns: [String]) -> Int {
        guard columns.count > 1 else { return 0 }
        if let index = columns.firstIndex(where: looksLikeServingColumn) {
            return index
        }
        return columns.firstIndex { !looksLikePer100($0) } ?? 0
    }

    private static func looksLikeServingColumn(_ header: String) -> Bool {
        guard !looksLikePer100(header), !looksLikeReferenceIntake(header) else { return false }
        let normalized = header.lowercased()
        return normalized.contains("serving") || normalized.contains("portion") || normalized.contains("pack")
            || normalized.contains(where: \.isNumber)
    }

    /// Reference Intake / %RI header text sometimes lands as two separate fragments — e.g.
    /// "Reference" and "Intake" on their own — rather than one combined "Reference Intake"
    /// segment, so an exact-token match is checked in addition to the combined phrase.
    private static func looksLikeReferenceIntake(_ header: String) -> Bool {
        let normalized = header.lowercased().replacingOccurrences(of: " ", with: "")
        if normalized.contains("referenceintake") || normalized.contains("%ri") || normalized.contains("ri*") {
            return true
        }
        return ["reference", "intake", "ri"].contains(normalized)
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
