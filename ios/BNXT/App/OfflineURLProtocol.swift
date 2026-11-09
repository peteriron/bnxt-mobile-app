#if DEBUG
import Foundation

/// Fails every request as if there were no connection, so UI tests can run the real app offline
/// (`--uitest-offline`, REQUIREMENTS §4 Offline). Registered for `URLSession.shared`, which every client uses.
final class OfflineURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
#endif
