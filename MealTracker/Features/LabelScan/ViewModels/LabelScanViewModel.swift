import Foundation
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
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
