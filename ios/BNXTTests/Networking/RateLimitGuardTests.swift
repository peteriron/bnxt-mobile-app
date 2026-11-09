@testable import BNXT
import XCTest

/// The client's own brakes on BNXT's per-IP rate limit (docs/bnxt-api.md "Polling policy", `RateLimitGuard`).
final class RateLimitGuardTests: XCTestCase {
    private var cacheDirectory: URL!
    private let fixedNow = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026
    private var router: MockURLProtocol.Router { MockURLProtocol.router }

    override func setUpWithError() throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "RateLimitGuardTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func assertThrows<T>(_ expected: APIError, file: StaticString = #filePath, line: UInt = #line,
                                 _ body: @escaping () async throws -> T) async {
        do {
            _ = try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? APIError, expected, file: file, line: line)
        }
    }

    func testBackoffDoublesUpToAMinute() {
        XCTAssertEqual((0...5).map(RateLimitGuard.backoff(after:)), [5, 10, 20, 40, 60, 60])
    }

    /// A clock the test moves forward.
    private final class Clock: @unchecked Sendable {
        var now: Date
        init(_ now: Date) { self.now = now }
    }

    private func guardedClient(_ clock: Clock) -> BNXTAPIClient {
        BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                      cache: ResponseCache(directory: cacheDirectory), now: { clock.now })
    }

    private let standingsPath = "standings/competition/25/phase/183"

    private func stubStandings(remaining: Int) throws {
        router.stub(standingsPath, body: try Fixture.data("standings"), headers: ["X-RateLimit-Remaining": "\(remaining)"])
    }

    func testBelowTwentyLeftTheCacheIsServedUntilTheWindowResets() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 19)
        _ = try await api.standings()

        clock.now += 30
        let held = try await api.standings()
        XCTAssertEqual(held.source, .cache, "served from the cache, so screens show their \"updated\" note")
        XCTAssertEqual(router.requests(to: standingsPath).count, 1)

        clock.now += 40 // past the ~65 s window
        _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 2)
    }

    func testTwentyOrMoreLeftKeepsAsking() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 20)
        _ = try await api.standings()
        _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 2)
    }

    func testLowOnRequestsWithNothingCachedStillAsks() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 5)
        _ = try await api.standings()
        try router.stub("competition-team/find/537", fixture: "team_537")

        _ = try await api.team(id: 537)
        XCTAssertEqual(router.requests(to: "competition-team/find/537").count, 1, "an empty screen is worse than one request")
    }

    func testATooManyRequestsAnswerHoldsOffForRetryAfter() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 150)
        _ = try await api.standings()
        router.stub(standingsPath, status: 429, body: Data(), headers: ["Retry-After": "30"])

        let first = try await api.standings()
        XCTAssertEqual(first.source, .cache)
        clock.now += 10
        _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 2, "held off: no request during Retry-After")

        clock.now += 21
        try stubStandings(remaining: 150)
        let fresh = try await api.standings()
        XCTAssertEqual(fresh.source, .network)
        XCTAssertEqual(router.requests(to: standingsPath).count, 3)
    }

    func testServerErrorsBackOffExponentiallyAndASuccessResets() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 150)
        _ = try await api.standings()
        router.stub(standingsPath, status: 503, body: Data())

        _ = try await api.standings()                                  // fails: hold 5 s
        clock.now += 4; _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 2)
        clock.now += 2; _ = try await api.standings()                  // asks, fails again: hold 10 s
        XCTAssertEqual(router.requests(to: standingsPath).count, 3)
        clock.now += 9; _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 3, "the second hold is longer")
        clock.now += 2
        try stubStandings(remaining: 150)
        _ = try await api.standings()                                  // succeeds: no more holding
        clock.now += 1; _ = try await api.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 5)
    }

    func testHoldingOffWithNothingCachedFailsWithoutARequest() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        router.stub(standingsPath, status: 429, body: Data(), headers: ["Retry-After": "30"])
        await assertThrows(APIError.rateLimited(retryAfter: 30)) { try await api.standings() }
        try router.stub("competition-team/find/537", fixture: "team_537")

        clock.now += 10
        do {
            _ = try await api.team(id: 537)
            XCTFail("expected rateLimited")
        } catch let APIError.rateLimited(retryAfter) {
            XCTAssertEqual(retryAfter ?? 0, 20, accuracy: 0.5, "how long is left")
        }
        XCTAssertTrue(router.requests(to: "competition-team/find/537").isEmpty)
    }

    func testCopiesOfTheClientShareOneGuard() async throws {
        let clock = Clock(fixedNow), api = guardedClient(clock)
        try stubStandings(remaining: 3)
        _ = try await api.standings()
        let copy = api // screens each hold a copy of AppModel's client
        _ = try await copy.standings()
        XCTAssertEqual(router.requests(to: standingsPath).count, 1)
    }
}
