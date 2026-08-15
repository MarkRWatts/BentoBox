import Foundation

struct OpenFoodFactsClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://world.openfoodfacts.org/api/v2/product/")!
    private let searchURL = URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!
    private let userAgent = "BentoBox/1.0 (iOS)"

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

        let response: OFFProductResponse = try await perform(url: url)
        return response
    }

    /// Text search by product name/brand — unlike `fetchProduct`, this can return many results,
    /// each carrying its own `code` (barcode) so a picked result can be cached/logged the same
    /// way a barcode scan match is.
    func searchProducts(query: String) async throws -> [OFFProduct] {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "20"),
            URLQueryItem(name: "fields", value: "code,product_name,brands,serving_size,nutriments")
        ]
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let response: OFFSearchResponse = try await perform(url: url)
        // A result with no barcode can't be cached or matched against future scans, so it isn't
        // usable here even though OFF occasionally returns one.
        return response.products.filter { $0.code?.isEmpty == false }
    }

    private func perform<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

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
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
