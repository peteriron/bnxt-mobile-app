import Foundation

enum APIError: Error, Equatable, Sendable {
    /// Built without `Secrets.xcconfig` (no API key) and nothing cached.
    case missingConfiguration
    /// 401: the key is missing or was rotated by the website (REQUIREMENTS §7.15).
    case unauthorized
    case notFound
    /// 429. `retryAfter` from the Retry-After header, in seconds.
    case rateLimited(retryAfter: TimeInterval?)
    case http(status: Int)
    /// Not an HTTP response.
    case invalidResponse
    /// The response didn't match the expected shape.
    case decoding(endpoint: String, message: String)
    case network(URLError.Code)
}
