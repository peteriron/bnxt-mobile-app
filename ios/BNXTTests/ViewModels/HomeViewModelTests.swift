@testable import BNXT
import XCTest

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "HomeViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func model(sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> HomeViewModel {
        let now = now
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: cacheDirectory), now: { now })
        return HomeViewModel(api: api, liveStats: LiveStatsClient(session: MockURLProtocol.session()), now: { now }, sleep: sleep)
    }

    /// The game slider with CHA–RCB (11351, genius 2873634) set to a status.
    private func slider(gameStatus status: String) throws -> Data {
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Fixture.data("game_slider")) as? [String: Any])
        var games = try XCTUnwrap(json["data"] as? [[String: Any]])
        let index = try XCTUnwrap(games.firstIndex { ($0["id"] as? Int) == 11351 })
        games[index]["status"] = status
        json["data"] = games
        return try JSONSerialization.data(withJSONObject: json)
    }

    private func stubAll() throws {
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        try router.stub("schedule/game-slider/25", fixture: "game_slider")
        try router.stub("competition-team/statistics-by-game/total/537", fixture: "team_games_537")
        try router.stub("competition-team/player-averages/537", fixture: "player_averages_537")
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
    }

    private let config = RemoteConfig.bundled()

    func testLoadsEverySection() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current, clubId: 537)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertNil(model.liveGame)
        XCTAssertEqual(model.nextGame?.id, 11351)
        XCTAssertEqual(model.lastResult?.id, 11339, "the club's game list reaches further than the slider")
        XCTAssertEqual(model.standing(config: config, clubs: [])?.standing.position, 4)
        XCTAssertEqual(model.clubLeaders.count, 4)
        XCTAssertEqual(model.aroundTheLeague.map(\.id), [11327, 11325, 11323])
        XCTAssertEqual(model.leagueLeaders.count, 3)
        XCTAssertNil(model.cachedAt)
    }

    func testMissingLeadersOnlyDropThatSection() async throws {
        try stubAll()
        router.fail("player/average-rankings/25")
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.leagueLeaders.isEmpty)
        XCTAssertEqual(model.nextGame?.id, 11351)
    }

    func testFailsWhenNothingLoads() async {
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertEqual(model.state, .failed)
    }

    /// Changing the favourite must not leave the old club's leaders or results under the new club's name.
    func testChangingClubDropsTheOldClubsData() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertFalse(model.clubLeaders.isEmpty)

        router.stub("competition-team/statistics-by-game/total/553", body: Data(#"{"data":[]}"#.utf8))
        router.stub("competition-team/player-averages/553", body: Data(#"{"data":[]}"#.utf8))
        await model.load(season: .current, clubId: 553)
        XCTAssertTrue(model.clubLeaders.isEmpty, "Liège's (empty) players, not Spirou's")
        XCTAssertEqual(model.lastResult?.id, 11327, "Liège's last game, from the slider")
        XCTAssertEqual(model.standing(config: config, clubs: [])?.standing.team.id, 553)
    }

    func testOfflineServesTheCache() async throws {
        try stubAll()
        await model().load(season: .current, clubId: 537)
        for path in ["standings/competition/25/phase/183", "schedule/game-slider/25",
                     "competition-team/statistics-by-game/total/537", "competition-team/player-averages/537"] {
            router.fail(path)
        }
        let offline = model()
        await offline.load(season: .current, clubId: 537)
        XCTAssertEqual(offline.state, .loaded)
        XCTAssertEqual(offline.nextGame?.id, 11351)
        XCTAssertNotNil(offline.cachedAt)
    }

    // MARK: Live

    func testLiveCardShowsTheFeedsScoreClockAndLastPlay() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "live"))
        try router.stub("/data/2873634/data.json", fixture: "livestats_11351_live")
        let router = router
        let finished = try slider(gameStatus: "finished")
        let model = model { _ in router.stub("schedule/game-slider/25", body: finished) } // the game ends after the first poll
        await model.load(season: .current, clubId: 537)
        XCTAssertEqual(model.liveGame?.id, 11351)
        XCTAssertNil(model.nextGame.map(\.id).flatMap { $0 == 11351 ? $0 : nil }, "the live game isn't also the next game")

        let watching = Task { await model.watchLive(season: .current, liveStatsEnabled: true) }
        // First poll: the feed. Then six sleeps until the slider is asked again and shows the final.
        await watching.value
        XCTAssertNil(model.liveGame, "finished: no live card")
        XCTAssertNil(model.liveFeed)
        XCTAssertEqual(router.requests(to: "/data/2873634/data.json").count, 6)
    }

    func testLiveCardShowsTheFeedWhileWatching() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "live"))
        try router.stub("/data/2873634/data.json", fixture: "livestats_11351_live")
        let model = model { _ in try await Task.sleep(for: .seconds(60)) } // stays between polls until cancelled
        await model.load(season: .current, clubId: 537)
        let watching = Task { await model.watchLive(season: .current, liveStatsEnabled: true) }
        for _ in 0..<200 where model.liveFeed == nil { try await Task.sleep(for: .milliseconds(10)) }

        XCTAssertEqual(model.liveGame?.home.score, 31, "the feed's score, not BNXT's")
        XCTAssertEqual(model.liveGame?.away.score, 30)
        XCTAssertEqual(model.liveGame?.period, "Q2 00:00")
        XCTAssertEqual(model.lastPlay, "T. Tumba · 3PT missed")

        watching.cancel() // Home went away
        await watching.value
        XCTAssertEqual(router.requests(to: "/data/2873634/data.json").count, 1)
        XCTAssertEqual(model.lastPlay, "T. Tumba · 3PT missed",
                       "kept, so coming back doesn't flash BNXT's older score before the next poll")
    }

    func testSwitchedOffByConfigNoFeedIsAsked() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "live"))
        let model = model { _ in throw CancellationError() }
        await model.load(season: .current, clubId: 537)
        await model.watchLive(season: .current, liveStatsEnabled: false)
        XCTAssertTrue(router.requests(to: "/data/2873634/data.json").isEmpty)
        XCTAssertNil(model.lastPlay)
    }

    // MARK: Next game beyond the slider

    /// The slider reaches about two weeks ahead: during a longer break Home showed no next game at all.
    func testNextGameBeyondTheSliderComesFromTheSchedule() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "finished")) // nothing left for 537
        try router.stub("schedule/club/2027", fixture: "schedule")
        let model = model()
        await model.load(season: .current, clubId: 537)

        XCTAssertEqual(model.nextGame?.id, 11743)
        let query = try XCTUnwrap(router.requests(to: "schedule/club/2027").first?.url?.query(percentEncoded: false))
        XCTAssertTrue(query.contains("competition_team_id=537"), query)
    }

    func testTheSlidersNextGameWinsOverTheSchedule() async throws {
        try stubAll()
        try router.stub("schedule/club/2027", fixture: "schedule")
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertEqual(model.nextGame?.id, 11351)
    }

    /// A stale cached schedule can still say `ready` for a game that has been played.
    func testAPastGameFromTheScheduleIsNotTheNextGame() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "finished"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: try Fixture.data("schedule")) as? [String: Any])
        let games = try XCTUnwrap(json["data"] as? [[String: Any]]).filter { ($0["id"] as? Int) != 11743 }.map { game -> [String: Any] in
            var game = game
            game["status"] = "ready"
            return game
        }
        json["data"] = games
        router.stub("schedule/club/2027", body: try JSONSerialization.data(withJSONObject: json))
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertNil(model.nextGame, "11279 has been played; the slider says 11351 has too")
    }

    func testChangingClubDropsTheOldClubsSchedule() async throws {
        try stubAll()
        router.stub("schedule/game-slider/25", body: try slider(gameStatus: "finished"))
        try router.stub("schedule/club/2027", fixture: "schedule")
        let model = model()
        await model.load(season: .current, clubId: 537)
        XCTAssertNotNil(model.nextGame)

        await model.load(season: .current, clubId: nil)
        XCTAssertNil(model.nextGame)
    }
}
