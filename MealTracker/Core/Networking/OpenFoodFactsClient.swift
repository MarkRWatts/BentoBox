import Foundation

struct OpenFoodFactsClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://world.openfoodfacts.org/api/v2/product/")!
    private let searchURL = URL(string: "https://world.openfoodfacts.org/cgi/search.pl")!
    private let userAgent = "ReTrack/1.0 (iOS)"

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

        // OFF's search endpoint is noticeably flakier than the single-product lookup — it
        // intermittently serves an HTML "temporarily unavailable" page with a 503 instead of
        // JSON, seemingly under normal load rather than only when truly down. That clears up
        // within a request or two, so retry a couple of times before surfacing an error rather
        // than failing the search on the first transient blip.
        var lastError: Error = NetworkError.invalidResponse
        for attempt in 0..<3 {
            do {
                let response: OFFSearchResponse = try await perform(url: url)
                return response.products.filter(\.isUsableSearchResult)
            } catch {
                lastError = error
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
        }
        throw lastError
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
