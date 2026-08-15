import Foundation

struct OpenFoodFactsClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://world.openfoodfacts.org/api/v2/product/")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProduct(barcode: String) async throws -> OFFProductResponse {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("\(barcode).json"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "code,status,product_name,brands,serving_size,nutriments")
        ]
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("MealTracker/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw NetworkError.transportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(OFFProductResponse.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
