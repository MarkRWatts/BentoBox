import Foundation
import FoundationModels
import Observation
import UIKit

@Observable
@MainActor
final class LabelScanViewModel {
    enum State {
        case idle
        case processing
        case ready(ExtractedNutritionLabel)
        case unavailable(String)
        case error(String)
    }

    private(set) var state: State = .idle

    func process(image: UIImage) async {
        state = .processing
        do {
            let ocrText = try await NutritionLabelOCRService.recognizeText(in: image)
            let extracted = try await NutritionLabelExtractor.extract(from: ocrText)
            state = .ready(extracted)
        } catch let error as NutritionLabelExtractor.ExtractionError {
            switch error {
            case .unavailable(let message):
                state = .unavailable(message)
            }
        } catch let error as LanguageModelSession.GenerationError {
            state = .unavailable(Self.message(for: error))
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }

    /// The framework's own error text (e.g. "An unsupported language or locale was used")
    /// doesn't tell the user what to do next, so add guidance for the cases we can act on.
    private static func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .unsupportedLanguageOrLocale:
            return "Apple Intelligence doesn't support your device's current language for this feature yet. You can change it under Settings > Apple Intelligence & Siri > Language, or enter the nutrition facts manually."
        case .guardrailViolation:
            return "Apple Intelligence couldn't process this photo. Try a clearer photo of just the label, or enter the nutrition facts manually."
        case .assetsUnavailable:
            return "Apple Intelligence is still downloading its on-device model. Try again shortly, or enter the nutrition facts manually."
        default:
            return "Apple Intelligence couldn't read this label (\(error.localizedDescription)). You can enter the nutrition facts manually instead."
        }
    }
}
