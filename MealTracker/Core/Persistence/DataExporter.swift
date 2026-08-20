import Foundation

/// Exports a profile's logged meals, weight history and water log as CSV, written to a temp
/// file for `ShareLink` to hand off to the system share sheet. Reads straight off the profile's
/// own SwiftData relationships (`mealSlots.entries`, `weightHistory`, `waterLog`) rather than a
/// `ModelContext` fetch — everything needed is already loaded in memory once a profile exists.
enum DataExporter {
    static func exportMealsCSV(profile: UserProfile) -> URL? {
        let entries = profile.mealSlots.flatMap(\.entries).sorted { $0.date < $1.date }

        var csv = "Date,Time,Meal,Food,Brand,Quantity,Serving Size,Calories,Protein (g),Carbs (g),Fat (g),Fiber (g),Sugar (g),Saturated Fat (g),Sodium (mg)\n"
        for entry in entries {
            let foodItem = entry.foodItem
            let fields: [String] = [
                dateFormatter.string(from: entry.date),
                timeFormatter.string(from: entry.date),
                csvField(entry.mealSlotNameSnapshot),
                csvField(foodItem?.name ?? ""),
                csvField(foodItem?.brand ?? ""),
                number(entry.quantity),
                csvField(foodItem?.servingSizeDescription ?? ""),
                number(entry.calories),
                number(entry.proteinGrams),
                number(entry.carbGrams),
                number(entry.fatGrams),
                number(entry.fiberGrams),
                number(entry.sugarGrams),
                number(entry.saturatedFatGrams),
                number(entry.sodiumMg)
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return write(csv, filename: "cal-track-meals.csv")
    }

    static func exportWeightCSV(profile: UserProfile) -> URL? {
        let history = profile.weightHistory.sorted { $0.date < $1.date }

        var csv = "Date,Weight (kg)\n"
        for entry in history {
            csv += "\(dateFormatter.string(from: entry.date)),\(number(entry.weightKG))\n"
        }
        return write(csv, filename: "cal-track-weight.csv")
    }

    static func exportWaterCSV(profile: UserProfile) -> URL? {
        let entries = profile.waterLog.sorted { $0.date < $1.date }

        var csv = "Date,Time,Volume (ml)\n"
        for entry in entries {
            let fields = [
                dateFormatter.string(from: entry.date),
                timeFormatter.string(from: entry.date),
                number(entry.volumeML)
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        return write(csv, filename: "cal-track-water.csv")
    }

    // MARK: - Formatting

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Fixed POSIX locale so the decimal separator is always "." regardless of device locale —
    /// CSV readers expect that, not a locale-dependent ",".
    private static func number(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// Quotes a field and escapes internal quotes wherever it might contain a comma, quote, or
    /// newline — food names and brands are free text pulled from Open Food Facts or typed by
    /// hand, so this is never guaranteed to be comma-free.
    private static func csvField(_ raw: String) -> String {
        guard raw.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return raw }
        return "\"\(raw.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func write(_ content: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
