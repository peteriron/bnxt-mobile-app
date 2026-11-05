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

    private func model() -> HomeViewModel {
        let now = now
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: cacheDirectory), now: { now })
        return HomeViewModel(api: api, now: { now })
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
}
