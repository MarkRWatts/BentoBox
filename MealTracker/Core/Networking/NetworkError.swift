import Foundation

enum NetworkError: Error, LocalizedError {
    case transportError(Error)
    case invalidResponse
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .transportError:
            return "Couldn't reach the network. Check your connection and try again."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .decodingError:
            return "Couldn't understand the server's response."
        }
    }
}
