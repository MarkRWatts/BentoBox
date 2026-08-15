import Foundation
import Vision
import UIKit

/// CGImage is safe to share across isolation domains (immutable, thread-safe under the hood),
/// but isn't formally Sendable — this box lets us cross into the detached Task without blocking
/// the caller's actor on the Vision request itself.
private struct SendableCGImage: @unchecked Sendable {
    let image: CGImage
}

enum NutritionLabelOCRService {
    enum OCRError: Error, LocalizedError {
        case invalidImage

        var errorDescription: String? {
            "Couldn't read that image."
        }
    }

    struct Fragment {
        let text: String
        let minX: CGFloat
        let midY: CGFloat
        let height: CGFloat
    }

    /// Runs Vision text recognition off the calling actor and reconstructs rows/columns from
    /// each fragment's position. A naive top-to-bottom text dump scrambles multi-column UK/EU
    /// style labels (e.g. "Per 100g" / "Per 40g serving" side by side) since Vision returns each
    /// fragment as an independent observation with no column awareness of its own.
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        let boxed = SendableCGImage(image: cgImage)

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: boxed.image, options: [:])
            try handler.perform([request])

            let observations = request.results ?? []
            let fragments: [Fragment] = observations.compactMap { observation in
                guard let text = observation.topCandidates(1).first?.string else { return nil }
                let box = observation.boundingBox
                return Fragment(text: text, minX: box.minX, midY: box.midY, height: box.height)
            }

            return Self.assembleRows(from: fragments)
        }.value
    }

    /// Reconstructs table rows in two passes. Pass 1 clusters fragments into visual lines by
    /// tight vertical overlap. Pass 2 merges wrapped lines back into the row above: a genuine new
    /// row always starts with a label near the left margin (e.g. "Energy", "Fat"), but a value
    /// that wraps onto a second line (e.g. "kJ" above "kcal" within one "Energy" cell) never does
    /// — so a line with nothing near the margin is folded into the previous row instead of
    /// starting a new one. Each row is then ordered left-to-right so values stay grouped with
    /// their column header, and a wrapped value naturally lands right next to its sibling since
    /// both occupy the same column position.
    static func assembleRows(from fragments: [Fragment]) -> String {
        guard !fragments.isEmpty else { return "" }

        let sorted = fragments.sorted { $0.midY > $1.midY }
        var lines: [[Fragment]] = []
        for fragment in sorted {
            if let lastIndex = lines.indices.last,
               let reference = lines[lastIndex].first,
               abs(fragment.midY - reference.midY) <= reference.height * 0.5 {
                lines[lastIndex].append(fragment)
            } else {
                lines.append([fragment])
            }
        }
        for i in lines.indices {
            lines[i].sort { $0.minX < $1.minX }
        }

        let labelMarginX = lines.compactMap(\.first).map(\.minX).min() ?? 0
        let linesNearMargin = lines.filter { ($0.first?.minX ?? 0) <= labelMarginX + 0.08 }.count

        // If the label column got cut off (e.g. by an over-tight crop), the remaining numeric
        // columns still share a rough left edge of their own, so a couple of lines can land
        // "near the margin" by pure coincidence even with no real row-name text anywhere — a low
        // bar here still let contamination through in testing. Require a genuine majority before
        // trusting the merge signal; merging under a false positive doesn't just fold wrapped
        // continuation lines, it collapses unrelated rows into one contaminated blob (real
        // failure seen on-device: Sugar's value ending up in the Carbs field, Salt's in Saturated
        // Fat). Otherwise keep every visual line as its own row.
        let requiredMarginLines = max(2, Int((Double(lines.count) * 0.6).rounded(.up)))
        let shouldMergeWrappedLines = linesNearMargin >= requiredMarginLines

        var rows: [[Fragment]] = []
        for line in lines {
            let startsNearLabelMargin = (line.first?.minX ?? 0) <= labelMarginX + 0.08
            if shouldMergeWrappedLines, !startsNearLabelMargin, let lastIndex = rows.indices.last {
                rows[lastIndex].append(contentsOf: line)
            } else {
                rows.append(line)
            }
        }

        return rows
            .map { row in row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " | ") }
            .joined(separator: "\n")
    }
}
