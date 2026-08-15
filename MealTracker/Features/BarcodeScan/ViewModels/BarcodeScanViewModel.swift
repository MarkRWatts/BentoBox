import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class BarcodeScanViewModel {
    enum State {
        case idle
        case lookingUp
        case found(FoodItem)
        case notFound(barcode: String)
        case error(String)
    }

    private(set) var state: State = .idle
    private let client: OpenFoodFactsClient

    init(client: OpenFoodFactsClient = OpenFoodFactsClient()) {
        self.client = client
    }

    func lookup(barcode: String, context: ModelContext) async {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state = .lookingUp

        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.barcode == trimmed })
        if let cached = try? context.fetch(descriptor).first {
            state = .found(cached)
            return
        }

        do {
            let response = try await client.fetchProduct(barcode: trimmed)
            guard let foodItem = OpenFoodFactsMapper.makeFoodItem(from: response, barcode: trimmed) else {
                state = .notFound(barcode: trimmed)
                return
            }
            context.insert(foodItem)
            try? context.save()
            state = .found(foodItem)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
    }
}
