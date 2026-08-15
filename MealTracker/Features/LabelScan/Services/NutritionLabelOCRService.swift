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

    /// Runs Vision text recognition off the calling actor and returns the recognized lines,
    /// roughly top-to-bottom as they appear on the label.
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
            let sorted = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }
            return sorted.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }
}
