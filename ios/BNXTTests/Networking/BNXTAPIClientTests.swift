@testable import BNXT
import XCTest

final class BNXTAPIClientTests: XCTestCase {
    private var cacheDirectory: URL!
    private let fixedNow = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026

    override func setUpWithError() throws {
        MockURLProtocol.router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "BNXTAPIClientTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        MockURLProtocol.router.reset()
    }

    private func client(key: String? = "test-key", cache: Bool = true) -> BNXTAPIClient {
        let now = fixedNow
        return BNXTAPIClient(configuration: key.map { APIConfiguration(apiKey: $0) },
                             session: MockURLProtocol.session(),
                             cache: cache ? ResponseCache(directory: cacheDirectory) : nil,
                             now: { now })
    }

    private var router: MockURLProtocol.Router { MockURLProtocol.router }

    // MARK: Requests

    func testSendsTheWebsitesHeadersAndLanguage() async throws {
        try router.stub("standings/competition/25/phase/183", fixture: "standings")

        _ = try await client().standings()

        let request = try XCTUnwrap(router.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Authorization"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Localization"), "en")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.url?.absoluteString, "https://bnxt.sportpress.info/api/v1/standings/competition/25/phase/183?lang=en")
    }

    /// Every endpoint hits the documented path and decodes its fixture (docs/bnxt-api.md).
    func testEveryEndpointHitsItsPathAndDecodes() async throws {
        let api = client()
        try router.stub("competition-team/all", fixture: "teams")
        try router.stub("competition-team/find/537", fixture: "team_537")
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        try router.stub("roster/team-players/537", fixture: "roster_537")
        try router.stub("competition-team/player-averages/537", fixture: "player_averages_537")
        try router.stub("competition-team/statistics-by-game/total/537", fixture: "team_games_537")
        try router.stub("schedule/game-slider/25", fixture: "game_slider")
        try router.stub("schedule/find/11323", fixture: "game_11323")
        try router.stub("boxscore/game/25/11323", fixture: "box_score_11323")
        try router.stub("boxscore/player/season-games/11173", fixture: "player_game_log_11173")
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
        try router.stub("roster/find/11173", fixture: "roster_entry_11173")

        let teams = try await api.teams().value.count
        let team = try await api.team(id: 537).value.statistics?.pointsFor
        let standings = try await api.standings().value.count
        let roster = try await api.roster(teamId: 537).value.count
        let averages = try await api.playerAverages(teamId: 537).value.count
        let teamGames = try await api.teamGames(teamId: 537).value.count
        let slider = try await api.gameSlider().value.count
        let game = try await api.game(id: 11323).value.away.score
        let box = try await api.boxScore(gameId: 11323, isFinal: true).value.home?.totals.points
        let log = try await api.playerGameLog(rosterId: 11173).value.count
        let leaders = try await api.playerLeaders().value[.points].count
        let entry = try await api.rosterEntry(id: 11173).value

        XCTAssertEqual(teams, 16)
        XCTAssertEqual(team, 79.8)
        XCTAssertEqual(standings, 16)
        XCTAssertEqual(roster, 13)
        XCTAssertEqual(averages, 12)
        XCTAssertEqual(teamGames, 5)
        XCTAssertEqual(slider, 6)
        XCTAssertEqual(game, 70)
        XCTAssertEqual(box, 65)
        XCTAssertEqual(log, 5)
        XCTAssertEqual(leaders, 5)
        XCTAssertEqual(entry.player.lastName, "Heath")
        XCTAssertEqual(entry.teamId, 537)
        XCTAssertEqual(entry.heightCm, 188)
        XCTAssertEqual(router.requests.count, 12)
        XCTAssertEqual(router.requests(to: "roster/team-players/537").first?.url?.query(), "competition_id=25&lang=en")
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").first?.url?.query(), "phase_id=183&lang=en")
    }

    // MARK: Errors

    func testMissingKeyFailsWithoutARequest() async {
        await assertThrows(APIError.missingConfiguration) { try await self.client(key: nil).standings() }
        XCTAssertTrue(router.requests.isEmpty)
    }

    func testMapsHTTPErrors() async {
        router.stub("standings/competition/25/phase/183", status: 401, body: Data())
        await assertThrows(APIError.unauthorized) { try await self.client(cache: false).standings() }

        router.stub("standings/competition/25/phase/183", status: 429, body: Data(), headers: ["Retry-After": "30"])
        await assertThrows(APIError.rateLimited(retryAfter: 30)) { try await self.client(cache: false).standings() }

        router.stub("standings/competition/25/phase/183", status: 503, body: Data())
        await assertThrows(APIError.http(status: 503)) { try await self.client(cache: false).standings() }

        router.fail("standings/competition/25/phase/183", with: .timedOut)
        await assertThrows(APIError.network(.timedOut)) { try await self.client(cache: false).standings() }
    }

    func testUnexpectedShapeIsADecodingError() async {
        router.stub("schedule/find/11323", body: Data(#"{"data":{"id":11323}}"#.utf8))
        do {
            _ = try await client(cache: false).game(id: 11323)
            XCTFail("Expected a decoding error")
        } catch let APIError.decoding(endpoint, _) {
            XCTAssertEqual(endpoint, "schedule/find/11323")
        } catch {
            XCTFail("Unexpected \(error)")
        }
    }

    // MARK: Cache and offline

    func testNetworkFailureServesTheCachedCopy() async throws {
        let api = client()
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        let fresh = try await api.standings()
        XCTAssertEqual(fresh.source, .network)
        XCTAssertEqual(fresh.fetchedAt, fixedNow)

        router.fail("standings/competition/25/phase/183")
        let offline = try await api.standings()

        XCTAssertEqual(offline.source, .cache)
        XCTAssertTrue(offline.isFallback)
        XCTAssertEqual(offline.value, fresh.value)
        XCTAssertEqual(offline.fetchedAt.timeIntervalSince1970, fixedNow.timeIntervalSince1970, accuracy: 1)
    }

    func testUnauthorizedAlsoFallsBackToCache() async throws {
        let api = client()
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        _ = try await api.standings()

        router.stub("standings/competition/25/phase/183", status: 401, body: Data()) // e.g. the website rotated its key
        let result = try await api.standings()
        XCTAssertEqual(result.source, .cache)
    }

    func testNoCacheAndNoNetworkThrows() async {
        router.fail("standings/competition/25/phase/183")
        await assertThrows(APIError.network(.notConnectedToInternet)) { try await self.client().standings() }
    }

    /// A finished game's box score never changes: the second open costs no request.
    func testFinishedBoxScoreIsServedFromCacheWithoutARequest() async throws {
        let api = client()
        try router.stub("boxscore/game/25/11323", fixture: "box_score_11323")

        _ = try await api.boxScore(gameId: 11323, isFinal: true)
        let second = try await api.boxScore(gameId: 11323, isFinal: true)

        XCTAssertEqual(second.source, .stored, "served on purpose, not as an offline fallback")
        XCTAssertFalse(second.isFallback)
        XCTAssertEqual(router.requests(to: "boxscore/game/25/11323").count, 1)
    }

    /// An empty cached box score may still be filled in, so it's not trusted.
    func testEmptyCachedBoxScoreIsRefetched() async throws {
        let api = client()
        router.stub("boxscore/game/25/11323", body: Data(#"{"data":[]}"#.utf8))
        _ = try await api.boxScore(gameId: 11323, isFinal: true)

        try router.stub("boxscore/game/25/11323", fixture: "box_score_11323")
        let refreshed = try await api.boxScore(gameId: 11323, isFinal: true)

        XCTAssertEqual(refreshed.source, .network)
        XCTAssertFalse(refreshed.value.isEmpty)
        XCTAssertEqual(router.requests(to: "boxscore/game/25/11323").count, 2)
    }

    func testLiveBoxScoreAlwaysAsksTheNetwork() async throws {
        let api = client()
        try router.stub("boxscore/game/25/11323", fixture: "box_score_11323")
        _ = try await api.boxScore(gameId: 11323, isFinal: false)
        _ = try await api.boxScore(gameId: 11323, isFinal: false)
        XCTAssertEqual(router.requests(to: "boxscore/game/25/11323").count, 2)
    }

    /// The leaders response is 1.4 MB and ~10 s: `.maxAge` reuses a young cached copy without a request.
    func testMaxAgeServesAYoungCacheAndRefetchesAnOldOne() async throws {
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
        func client(at date: Date) -> BNXTAPIClient {
            BNXTAPIClient(configuration: APIConfiguration(apiKey: "k"), session: MockURLProtocol.session(),
                          cache: ResponseCache(directory: cacheDirectory), now: { date })
        }
        let first = try await client(at: fixedNow).playerLeaders(cachePolicy: .maxAge(3600))
        XCTAssertEqual(first.source, .network)

        let young = try await client(at: fixedNow.addingTimeInterval(1800)).playerLeaders(cachePolicy: .maxAge(3600))
        XCTAssertEqual(young.source, .stored)
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").count, 1, "no request for a 30-minute-old copy")

        let old = try await client(at: fixedNow.addingTimeInterval(7200)).playerLeaders(cachePolicy: .maxAge(3600))
        XCTAssertEqual(old.source, .network)
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").count, 2)

        _ = try await client(at: fixedNow.addingTimeInterval(7300)).playerLeaders()
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").count, 3, "networkFirst ignores the cache's age")
    }

    /// §7.16: the cache must not hold fields we never decode, even if the API starts filling them in.
    func testCacheNeverStoresForbiddenFields() async throws {
        let player = #"{"id":2,"first_name":"A","last_name":"B","facebook":"fb.com/x","instagram":"@x","twitter":"@x","description":"bio"}"#
        let body = #"{"data":[{"id":1,"jersey":"5","player":"# + player + "}]}"
        router.stub("roster/team-players/537", body: Data(body.utf8))

        _ = try await client().roster(teamId: 537)

        let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        let cached = try String(contentsOf: files[0], encoding: .utf8)
        XCTAssertTrue(cached.contains("\"last_name\""))
        // A fixed list, not PrivacyFilter.neverStoredKeys: emptying the filter must fail this test.
        for key in ["facebook", "twitter", "instagram", "description"] {
            XCTAssertFalse(cached.contains(key), "cache holds \(key)")
        }
    }

    /// §7.16: `roster/find` is the endpoint that sends the free-text `description` (docs/bnxt-api.md).
    func testRosterEntryNeverStoresTheDescription() async throws {
        let player = #"{"id":212,"first_name":"Joshua","last_name":"Heath","description":"<p>bio</p>","instagram":"@x"}"#
        let body = #"{"data":{"id":11173,"competition_team_id":537,"description":"x","player":"# + player + "}}"
        router.stub("roster/find/11173", body: Data(body.utf8))

        let entry = try await client().rosterEntry(id: 11173).value
        XCTAssertEqual(entry.player.lastName, "Heath")

        let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let cached = try String(contentsOf: try XCTUnwrap(files.first), encoding: .utf8)
        XCTAssertTrue(cached.contains("Heath"))
        XCTAssertFalse(cached.contains("description"))
        XCTAssertFalse(cached.contains("bio"))
        XCTAssertFalse(cached.contains("instagram"))
    }

    func testFilterCoversEveryNeverDecodedField() {
        XCTAssertEqual(PrivacyFilter.neverStoredKeys, ["facebook", "twitter", "instagram", "description"])
    }

    func testCacheKeyIgnoresTheAPIKey() {
        XCTAssertEqual(BNXTAPIClient.Endpoint("a", ["z": "1", "b": "2"]).cacheKey, "a?b=2&z=1")
        XCTAssertFalse(BNXTAPIClient.Endpoint("a").cacheKey.contains("test-key"))
    }

    // MARK: Helpers

    private func assertThrows<T>(_ expected: APIError, file: StaticString = #filePath, line: UInt = #line,
                                 _ body: @escaping () async throws -> T) async {
        do {
            _ = try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as APIError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected \(error)", file: file, line: line)
        }
    }

    // MARK: Full schedule

    /// `schedule/club` takes the season, not the competition id, and `month=-1` means all months (docs/bnxt-api.md).
    func testScheduleAsksForTheWholeSeason() async throws {
        try MockURLProtocol.router.stub("schedule/club/2027", fixture: "schedule")
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session())

        let games = try await api.schedule(seasonId: 2027).value
        XCTAssertEqual(games.count, 4)

        let query = try XCTUnwrap(MockURLProtocol.router.requests(to: "schedule/club/2027").first?.url?.query(percentEncoded: false))
        XCTAssertTrue(query.contains("clubs[0]=1"), query)
        XCTAssertTrue(query.contains("clubs[1]=2"), query)
        XCTAssertTrue(query.contains("month=-1"), query)
        XCTAssertFalse(query.contains("competition_team_id"), query)
    }

    func testScheduleCanBeLimitedToOneClub() async throws {
        try MockURLProtocol.router.stub("schedule/club/2027", fixture: "schedule")
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session())

        _ = try await api.schedule(seasonId: 2027, teamId: 537)
        let query = try XCTUnwrap(MockURLProtocol.router.requests(to: "schedule/club/2027").first?.url?.query(percentEncoded: false))
        XCTAssertTrue(query.contains("competition_team_id=537"), query)
    }
}

final class ResponseCacheTests: XCTestCase {
    func testRoundTripsDataAndDate() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ResponseCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = ResponseCache(directory: directory)
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        XCTAssertNil(cache.read("a"))
        cache.write(Data("one".utf8), for: "a", at: date)
        cache.write(Data("two".utf8), for: "b", at: date)

        XCTAssertEqual(cache.read("a")?.data, Data("one".utf8))
        XCTAssertEqual(try XCTUnwrap(cache.read("a")?.storedAt).timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1)
        XCTAssertNotEqual(cache.fileURL(for: "a"), cache.fileURL(for: "b"))
        cache.removeAll()
        XCTAssertNil(cache.read("b"))
    }

    func testPrivacyFilterStripsNestedKeysAndRejectsNonJSON() throws {
        let input = Data(#"{"a":{"facebook":"x","keep":[{"description":"y","b":1}]}}"#.utf8)
        let output = try XCTUnwrap(PrivacyFilter.sanitized(input))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: output) as? [String: Any])
        let nested = try XCTUnwrap(object["a"] as? [String: Any])
        XCTAssertNil(nested["facebook"])
        XCTAssertEqual((nested["keep"] as? [[String: Any]])?.first?.keys.sorted(), ["b"])
        XCTAssertNil(PrivacyFilter.sanitized(Data("<html>".utf8)))
    }
}
