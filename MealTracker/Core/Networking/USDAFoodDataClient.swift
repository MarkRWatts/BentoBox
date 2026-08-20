import Foundation

/// Fallback food-data source, tried only when Open Food Facts comes back empty or errors (see
/// `AddFoodView.search()`) — OFF skews toward packaged/international goods, USDA's catalog fills
/// in generic and US-branded foods OFF's crowd-sourced database tends to miss.
struct USDAFoodDataClient {
    /// Free at https://api.data.gov/signup, no Apple account or payment involved. `DEMO_KEY`
    /// works out of the box but is rate-limited to 30 requests/hour/IP and shared across every
    /// app using the default — swap in a real key once you have one, nothing else here changes.
    /// `nonisolated(unsafe)` since this is write-once app configuration, not state mutated
    /// concurrently at runtime.
    nonisolated(unsafe) static var apiKey = "DEMO_KEY"

    private let session: URLSession
    private let searchURL = URL(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchFoods(query: String) async throws -> [USDAFood] {
        var components = URLComponents(url: searchURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: Self.apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "20"),
            // Restricts to the data types with reliably-structured nutrition — excludes
            // "Experimental" and the more sparsely-populated survey (FNDDS) entries.
            URLQueryItem(name: "dataType", value: "Branded,Foundation,SR Legacy")
        ]
        guard let url = components?.url else {
            throw NetworkError.invalidResponse
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: URLRequest(url: url))
        } catch {
            throw NetworkError.transportError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }

        do {
            let decoded = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            return decoded.foods.filter(\.isUsableSearchResult)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }
}
