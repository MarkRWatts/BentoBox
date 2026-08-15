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

    private struct Fragment {
        let text: String
        let midY: CGFloat
        let minX: CGFloat
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
                return Fragment(text: text, midY: box.midY, minX: box.minX, height: box.height)
            }

            return Self.assembleRows(from: fragments)
        }.value
    }

    /// Clusters fragments into rows by vertical overlap (within ~60% of a fragment's own height),
    /// then orders each row left-to-right so values stay grouped with their column header.
    private static func assembleRows(from fragments: [Fragment]) -> String {
        let sorted = fragments.sorted { $0.midY > $1.midY }

        var rows: [[Fragment]] = []
        for fragment in sorted {
            if let lastIndex = rows.indices.last,
               let reference = rows[lastIndex].first,
               abs(fragment.midY - reference.midY) <= reference.height * 0.6 {
                rows[lastIndex].append(fragment)
            } else {
                rows.append([fragment])
            }
        }

        return rows
            .map { row in row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " | ") }
            .joined(separator: "\n")
    }
}
