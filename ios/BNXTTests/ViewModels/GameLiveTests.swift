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

    // MARK: The gap after the final whistle (recorded 5 Nov 2026, docs/bnxt-api.md)

    /// BNXT says `finished` with the score but no quarters or box score, and FIBA has both.
    private func stubFinalWhistleGap() throws {
        try stubLive()
        try router.stub(feedPath, fixture: "livestats_11351_final")
        try router.stub("roster/team-players/537", fixture: "roster_537")
        router.stub("roster/team-players/551", body: Data(#"{"data":[]}"#.utf8))
    }

    func testBoxScoreAndQuartersDoNotVanishAtTheFinalWhistle() async throws {
        try stubFinalWhistleGap()
        let model = model()
        await model.load(season: .current)
        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: false)

        try router.stub("schedule/find/11351", fixture: "game_11351_final_no_quarters")
        await model.refreshLive(season: .current, liveStatsEnabled: true, refreshGame: true)

        XCTAssertEqual(model.game?.status, .finished)
        XCTAssertEqual(model.tabs, [.summary, .boxScore, .info])
        XCTAssertEqual(model.game?.home.score, 77)
        XCTAssertEqual(model.game?.away.score, 74)
        XCTAssertEqual(model.game?.home.periodScores, [20, 11, 24, 22])
        XCTAssertEqual(model.game?.away.periodScores, [17, 13, 17, 27])
        XCTAssertNil(model.game?.period, "a finished game has no running clock")
        XCTAssertTrue(model.isLiveBox)
        XCTAssertEqual(model.teamBox(.home)?.totals.points, 77)
    }

    func testOpeningAGameDuringTheGapAfterTheFinalShowsTheFeedsData() async throws {
        try stubFinalWhistleGap()
        try router.stub("schedule/find/11351", fixture: "game_11351_final_no_quarters")
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.game?.home.periodScores, [20, 11, 24, 22])
        XCTAssertEqual(model.teamBox(.away)?.totals.points, 74)
        XCTAssertEqual(router.requests(to: feedPath).count, 1)
    }

    func testAFinishedGameWithoutQuartersIsNotCachedAsFinal() async throws {
        try stubFinalWhistleGap()
        try router.stub("schedule/find/11351", fixture: "game_11351_final_no_quarters")
        await model().load(season: .current)

        // BNXT publishes its final data; a later visit has to ask again to see it.
        try router.stub("schedule/find/11351", fixture: "game_11323")
        try router.stub("boxscore/game/25/11351", fixture: "box_score_11323")
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(router.requests(to: "schedule/find/11351").count, 2)
        XCTAssertFalse(model.game?.home.periodScores.isEmpty ?? true)
        XCTAssertNotEqual(model.game?.home.periodScores, [20, 11, 24, 22], "BNXT's quarters, not the feed's")
        XCTAssertFalse(model.isLiveBox)
        XCTAssertEqual(router.requests(to: feedPath).count, 1, "only the visit during the gap asked the feed")
    }

    func testAFeedDisagreeingWithBNXTsFinalScoreIsNotShown() async throws {
        try stubFinalWhistleGap()
        try router.stub("schedule/find/11351", fixture: "game_11351_final_no_quarters")
        try router.stub(feedPath, fixture: "livestats_feed") // 52-49 in Q3: a stale or wrong feed
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.game?.home.score, 77)
        XCTAssertEqual(model.game?.home.periodScores, [])
        XCTAssertFalse(model.isLiveBox)
    }

    func testSwitchedOffByConfigTheFinalWhistleDoesNotAskTheFeed() async throws {
        try stubFinalWhistleGap()
        let model = model()
        await model.load(season: .current)
        let before = router.requests(to: feedPath).count

        try router.stub("schedule/find/11351", fixture: "game_11351_final_no_quarters")
        await model.refreshLive(season: .current, liveStatsEnabled: false, refreshGame: true)

        XCTAssertEqual(router.requests(to: feedPath).count, before)
        XCTAssertEqual(model.game?.status, .finished)
        XCTAssertNil(model.liveFeed)
    }

    /// BNXT's first box score lacked a player, and minutes kept changing for at least two minutes (5 Nov 2026).
    func testAnEarlyFinalBoxScoreIsNotCachedAsFinal() async throws {
        try stubFinalWhistleGap()
        try router.stub("schedule/find/11351", fixture: "game_11351_final")
        try router.stub("boxscore/game/25/11351", fixture: "box_score_11323")
        let boxPath = "boxscore/game/25/11351"
        let tipOff = try XCTUnwrap(GameTime.parse("2026-11-05 20:30:00"))
        func load(at now: Date) async {
            let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                    cache: ResponseCache(directory: cacheDirectory), now: { now })
            await GameViewModel(gameId: 11351, api: api, liveStats: LiveStatsClient(session: MockURLProtocol.session()),
                                sleep: { _ in }).load(season: .current)
        }

        await load(at: tipOff.addingTimeInterval(2 * 3600 + 10 * 60))
        await load(at: tipOff.addingTimeInterval(2 * 3600 + 20 * 60))
        XCTAssertEqual(router.requests(to: boxPath).count, 2, "still settling: asked again")

        await load(at: tipOff.addingTimeInterval(3 * 3600 + 60))
        XCTAssertEqual(router.requests(to: boxPath).count, 3, "what was stored early isn't trusted later")

        await load(at: tipOff.addingTimeInterval(4 * 3600))
        XCTAssertEqual(router.requests(to: boxPath).count, 3, "stored after it settled: served from the cache")
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
