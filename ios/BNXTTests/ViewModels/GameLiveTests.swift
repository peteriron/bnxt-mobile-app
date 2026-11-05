@testable import BNXT
import XCTest

/// Phase 4 / §7.4: a live game polls the FIBA feed while its screen is visible and stops at the final whistle.
@MainActor
final class GameLiveTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400)
    private let feedPath = "/data/2873634/data.json"

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "GameLiveTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    /// CHA–RCB (11351) with the status the API sent at tip-off on 5 Nov 2026.
    private func gameJSON(status: String) throws -> Data {
        let text = try XCTUnwrap(String(data: try Fixture.data("game_11351_upcoming"), encoding: .utf8))
        return Data(text.replacingOccurrences(of: #""status": "ready""#, with: #""status": "\#(status)""#).utf8)
    }

    private func model(sleep: @escaping @Sendable (Duration) async throws -> Void = { _ in }) -> GameViewModel {
        let now = now
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: cacheDirectory), now: { now })
        return GameViewModel(gameId: 11351, api: api, liveStats: LiveStatsClient(session: MockURLProtocol.session()), sleep: sleep)
    }

    private func stubLive() throws {
        router.stub("schedule/find/11351", body: try gameJSON(status: "live"))
        router.stub("boxscore/game/25/11351", body: Data(#"{"data":[]}"#.utf8))
        try router.stub("schedule/game-slider/25", fixture: "game_slider")
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        try router.stub(feedPath, fixture: "livestats_feed")
    }

    func testAPollShowsTheFeedsScoreClockAndPlays() async throws {
        try stubLive()
        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.game?.isLive, true)
        XCTAssertEqual(model.tabs.first, .playByPlay)

        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertEqual(model.game?.home.score, 52)
        XCTAssertEqual(model.game?.period, "Q3 07:42")
        XCTAssertEqual(model.liveFeed?.plays.first?.id, 210)
        XCTAssertEqual(router.requests(to: "schedule/game-slider/25").count, 1, "the FIBA id comes from the slider")

        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertEqual(router.requests(to: "schedule/game-slider/25").count, 1, "looked up once")
        XCTAssertEqual(router.requests(to: feedPath).count, 2)
    }

    func testWhileBNXTsBoxScoreIsEmptyTheFeedsIsShown() async throws {
        try stubLive()
        try router.stub("/data/2873634/data.json", fixture: "livestats_11351_live")
        try router.stub("roster/team-players/537", fixture: "roster_537")
        router.stub("roster/team-players/551", body: Data(#"{"data":[]}"#.utf8))
        let model = model()
        await model.load(season: .current)
        XCTAssertNil(model.teamBox(.home)?.players.first, "BNXT's box score is empty while live")

        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertTrue(model.isLiveBox)
        XCTAssertEqual(model.teamBox(.home)?.totals.points, 31)
        XCTAssertTrue(model.teamBox(.home)?.players.contains { $0.rosterId == 11173 } == true)

        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertEqual(router.requests(to: "roster/team-players/537").count, 1, "rosters are loaded once")
    }

    func testBNXTsBoxScoreWinsOnceItHasLines() async throws {
        try stubLive()
        try router.stub("/data/2873634/data.json", fixture: "livestats_11351_live")
        try router.stub("boxscore/game/25/11351", fixture: "box_score_11323")
        let model = model()
        await model.load(season: .current)
        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertFalse(model.isLiveBox)
    }

    func testSwitchedOffByConfigTheFeedIsNotAskedAndBNXTsScoreShows() async throws {
        try stubLive()
        let model = model()
        await model.load(season: .current)
        await model.refreshLive(season: .current, liveStatsEnabled: false, refreshGame: false)
        XCTAssertTrue(router.requests(to: feedPath).isEmpty)
        XCTAssertNil(model.liveFeed)
        XCTAssertEqual(model.game?.home.score, 0)
    }

    func testAFailingFeedKeepsTheLastOne() async throws {
        try stubLive()
        let model = model()
        await model.load(season: .current)
        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        router.fail(feedPath)
        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)
        XCTAssertEqual(model.game?.home.score, 52)
    }

    func testBNXTIsAskedEverySixthPollWithTheFeedAndEveryThirdWithout() {
        XCTAssertEqual((0..<13).filter { GameViewModel.refreshesGame(onPoll: $0, liveStatsEnabled: true) }, [6, 12])
        XCTAssertEqual((0..<10).filter { GameViewModel.refreshesGame(onPoll: $0, liveStatsEnabled: false) }, [3, 6, 9])
        XCTAssertEqual(GameViewModel.livePollInterval, .seconds(10))
    }

    /// The loop ends by itself once BNXT reports the game finished, and the final view replaces the live one.
    func testWatchingStopsAtTheFinalWhistle() async throws {
        try stubLive()
        let finished = try gameJSON(status: "finished")
        let router = router
        let model = model { _ in
            // Between polls the game ends.
            router.stub("schedule/find/11351", body: finished)
        }
        await model.load(season: .current)
        await model.watchLive(season: .current, liveStatsEnabled: false) // returns: no hang
        XCTAssertEqual(model.game?.status, .finished)
        XCTAssertNil(model.liveFeed)
        XCTAssertEqual(model.tabs, [.summary, .boxScore, .info])
    }

    func testWatchingStopsWhenTheScreenGoesAway() async throws {
        try stubLive()
        let model = model { _ in throw CancellationError() } // the screen's task was cancelled during the wait
        await model.load(season: .current)
        await model.watchLive(season: .current, liveStatsEnabled: true)
        XCTAssertEqual(router.requests(to: feedPath).count, 1, "one poll, then it stopped")
        XCTAssertEqual(model.game?.isLive, true)
    }
}
