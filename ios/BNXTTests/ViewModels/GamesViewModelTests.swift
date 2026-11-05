@testable import BNXT
import XCTest

@MainActor
final class GamesViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "GamesViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private var api: BNXTAPIClient {
        let now = Date(timeIntervalSince1970: 1_793_750_400)
        return BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                             cache: ResponseCache(directory: cacheDirectory), now: { now })
    }

    // MARK: Games tab

    func testGamesTabLoadsAndFilters() async throws {
        try router.stub("schedule/game-slider/25", fixture: "game_slider")
        let model = GamesViewModel(api: api)
        await model.load(season: .current)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.sections(favoriteId: 537).days.flatMap(\.games).count, 3, "filter off: all clubs")

        model.onlyMyClub = true
        XCTAssertEqual(model.sections(favoriteId: 537).days.flatMap(\.games).map(\.id), [11351])
        model.mode = .results
        XCTAssertEqual(model.sections(favoriteId: 537).days.flatMap(\.games).map(\.id), [11323])
    }

    func testGamesTabFailsOnlyWithNothingToShow() async throws {
        router.fail("schedule/game-slider/25")
        let model = GamesViewModel(api: api)
        await model.load(season: .current)
        XCTAssertEqual(model.state, .failed)
    }

    // MARK: Game detail

    private func stubFinished() throws {
        try router.stub("schedule/find/11323", fixture: "game_11323")
        try router.stub("boxscore/game/25/11323", fixture: "box_score_11323")
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
    }

    func testFinishedGameLoadsTheBoxScore() async throws {
        try stubFinished()
        let model = GameViewModel(gameId: 11323, api: api)
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.tabs, [.summary, .boxScore, .info])
        XCTAssertEqual(model.selectedTab, .summary)
        XCTAssertEqual(model.teamBox(.home)?.team.id, 537)
        XCTAssertEqual(model.teamBox(.away)?.team.id, 539)
        XCTAssertEqual(model.standings[537]?.position, 4)
        XCTAssertTrue(router.requests(to: "competition-team/player-averages/537").isEmpty, "no preview data for a finished game")
    }

    /// A finished game never changes: the second visit makes no game or box-score request.
    func testFinishedGameIsServedFromTheCacheNextTime() async throws {
        try stubFinished()
        await GameViewModel(gameId: 11323, api: api).load(season: .current)
        let model = GameViewModel(gameId: 11323, api: api)
        await model.load(season: .current)
        XCTAssertEqual(router.requests(to: "schedule/find/11323").count, 1)
        XCTAssertEqual(router.requests(to: "boxscore/game/25/11323").count, 1)
        XCTAssertNotNil(model.teamBox(.home))
    }

    /// Bug: a finished game served from the cache by design showed "Offline · updated 57 minutes ago" while online.
    func testFinishedGameFromTheCacheIsNotShownAsOffline() async throws {
        try stubFinished()
        await GameViewModel(gameId: 11323, api: api).load(season: .current)
        let model = GameViewModel(gameId: 11323, api: api)
        await model.load(season: .current)
        XCTAssertNil(model.cachedAt, "the network is fine; only the immutable game and box score came from the cache")

        router.fail("standings/competition/25/phase/183")
        let offline = GameViewModel(gameId: 11323, api: api)
        await offline.load(season: .current)
        XCTAssertNotNil(offline.cachedAt, "a real fallback still says so")
    }

    func testUnavailableTabFallsBackToTheFirst() async throws {
        try stubFinished()
        let model = GameViewModel(gameId: 11323, api: api)
        model.tab = .preview
        await model.load(season: .current)
        XCTAssertEqual(model.selectedTab, .summary)
    }

    func testUpcomingGameLoadsThePreview() async throws {
        try router.stub("schedule/find/11351", fixture: "game_11351_upcoming")
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        for team in [537, 551] { // RCB answers with Spirou's lists: only the shape matters here
            try router.stub("competition-team/find/\(team)", fixture: "team_537")
            try router.stub("competition-team/player-averages/\(team)", fixture: "player_averages_537")
            try router.stub("competition-team/statistics-by-game/total/\(team)", fixture: "team_games_537")
        }
        let model = GameViewModel(gameId: 11351, api: api)
        await model.load(season: .current)

        XCTAssertEqual(model.tabs, [.preview, .info])
        XCTAssertNil(model.box)
        XCTAssertTrue(router.requests(to: "boxscore/game/25/11351").isEmpty)
        XCTAssertEqual(model.players[537]?.count, 12)
        XCTAssertNotNil(model.teamForm(teamId: 537).rebounds)
        XCTAssertEqual(model.form(teamId: 537), [false, true, true, false, true])
        XCTAssertTrue(model.earlierMeetings.isEmpty, "CHA and RCB haven't met yet")
    }

    func testGameFailsWithoutTheGame() async throws {
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        let model = GameViewModel(gameId: 11323, api: api)
        await model.load(season: .current)
        XCTAssertEqual(model.state, .failed)
    }
}
