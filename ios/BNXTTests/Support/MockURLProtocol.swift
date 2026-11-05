@testable import BNXT
import Foundation
import XCTest

/// The one network mock (playbook 03): intercepts every request made through `MockURLProtocol.session()`.
/// Answers by API path (the part after `/api/v1/`), records every request, and can fail chosen paths.
/// Reuse it; never write a second mock.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub: Sendable {
        var status: Int = 200
        var body: Data
        var headers: [String: String] = [:]
    }

    /// Shared state for the current test. XCTest runs a target's tests serially, so a lock is enough.
    final class Router: @unchecked Sendable {
        private let lock = NSLock()
        private var stubs: [String: Stub] = [:]
        private var failures: [String: URLError.Code] = [:]
        private var recorded: [URLRequest] = []

        func reset() {
            lock.withLock { stubs = [:]; failures = [:]; recorded = [] }
        }

        func stub(_ path: String, status: Int = 200, body: Data, headers: [String: String] = [:]) {
            lock.withLock { stubs[path] = Stub(status: status, body: body, headers: headers) }
        }

        /// Answers `path` with a fixture from BNXTTests/Fixtures.
        func stub(_ path: String, fixture: String) throws {
            stub(path, body: try Fixture.data(fixture))
        }

        func fail(_ path: String, with code: URLError.Code = .notConnectedToInternet) {
            lock.withLock { failures[path] = code }
        }

        var requests: [URLRequest] { lock.withLock { recorded } }

        func requests(to path: String) -> [URLRequest] {
            requests.filter { Self.apiPath(of: $0) == path }
        }

        fileprivate func respond(to request: URLRequest) -> Result<(HTTPURLResponse, Data), URLError> {
            lock.withLock {
                recorded.append(request)
                let path = Self.apiPath(of: request)
                if let code = failures[path] { return .failure(URLError(code)) }
                let stub = stubs[path] ?? Stub(status: 404, body: Data(#"{"errors":[{"code":"404"}]}"#.utf8))
                let response = HTTPURLResponse(url: request.url!, statusCode: stub.status, httpVersion: "HTTP/1.1", // swiftlint:disable:this force_unwrapping
                                               headerFields: stub.headers)!                                        // swiftlint:disable:this force_unwrapping
                return .success((response, stub.body))
            }
        }

        static func apiPath(of request: URLRequest) -> String {
            let path = request.url?.path() ?? ""
            guard let range = path.range(of: "/api/v1/") else { return path }
            return String(path[range.upperBound...])
        }
    }

    static let router = Router()

    /// A session whose requests all go through this mock.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        switch Self.router.respond(to: request) {
        case let .success((response, data)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// Golden fixtures: real API responses captured by tools/make_fixtures.py, never-decode fields stripped.
enum Fixture {
    private final class Token {}

    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Token.self).url(forResource: name, withExtension: "json"),
                                "Missing fixture \(name).json (regenerate the project after adding fixtures)")
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, from name: String) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }

    /// Decodes an enveloped list the way the client does: `{ "data": [ … ] }`, bad elements dropped.
    static func list<T: Decodable>(_ type: T.Type, from name: String) throws -> [T] {
        try decode(Envelope<LossyArray<T>>.self, from: name).data.elements
    }
}
