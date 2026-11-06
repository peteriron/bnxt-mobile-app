@testable import BNXT
import XCTest

@MainActor
final class ClubViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "ClubViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func model() -> ClubViewModel {
        let now = Date(timeIntervalSince1970: 1_793_750_400)
        return ClubViewModel(clubId: 537, api: BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                                            cache: ResponseCache(directory: cacheDirectory), now: { now }))
    }

    private func stubAll() throws {
        try router.stub("competition-team/find/537", fixture: "team_537")
        try router.stub("standings/competition/25/phase/183", fixture: "standings")
        try router.stub("roster/team-players/537", fixture: "roster_537")
        try router.stub("competition-team/player-averages/537", fixture: "player_averages_537")
        try router.stub("competition-team/statistics-by-game/total/537", fixture: "team_games_537")
        try router.stub("schedule/game-slider/25", fixture: "game_slider")
        // The latest result is 11339; any Spirou box score shows the jersey lookup.
        try router.stub("boxscore/game/25/11339", fixture: "box_score_11323")
    }

    func testLoadsEverySection() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertNil(model.cachedAt)
        XCTAssertEqual(model.team?.id, 537)
        XCTAssertNotNil(model.team?.statistics, "PPG and Opp PPG come from the team's statistics")
        XCTAssertEqual(model.standing?.position, 4)
        XCTAssertEqual(model.arena, "Dôme")
        XCTAssertEqual(model.results.map(\.id), [11339, 11323, 11303, 11293, 11279], "slider duplicates removed")
        XCTAssertEqual(model.upcoming.map(\.id), [11351])
        XCTAssertEqual(model.form, [false, true, true, false, true])
        XCTAssertEqual(model.rosterRows.count, 13)
        XCTAssertEqual(model.rosterRows.first { $0.entry.player.lastName == "Heath" }?.jersey, "3")
        XCTAssertEqual(model.playerStats.first?.player.lastName, "Konieczny Jr")

        model.statSort = .assists
        let assists = model.playerStats.map(\.perGame.assists)
        XCTAssertEqual(assists, assists.sorted(by: >))
    }

    func testOneFailedRequestDoesNotEmptyThePage() async throws {
        try stubAll()
        router.fail("roster/team-players/537")
        router.fail("boxscore/game/25/11339")
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertTrue(model.rosterRows.isEmpty)
        XCTAssertEqual(model.results.count, 5)
        XCTAssertEqual(model.standing?.position, 4)
    }

    func testFailsWhenNothingLoadsAndNothingIsCached() async {
        let model = model() // every path 404s
        await model.load(season: .current)
        XCTAssertEqual(model.state, .failed)
    }

    func testOfflineServesTheCache() async throws {
        try stubAll()
        await model().load(season: .current)
        router.reset()
        for path in ["competition-team/find/537", "standings/competition/25/phase/183", "roster/team-players/537",
                     "competition-team/player-averages/537", "competition-team/statistics-by-game/total/537", "schedule/game-slider/25"] {
            router.fail(path)
        }

        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.cachedAt)
        XCTAssertEqual(model.rosterRows.count, 13)
        XCTAssertEqual(model.rosterRows.first { $0.entry.player.lastName == "Heath" }?.jersey, "3", "finished box score served from cache")
    }

    /// The slider reaches about two weeks ahead; the club's Games tab shows the rest of the season.
    func testUpcomingReachesTheEndOfTheSeason() async throws {
        try stubAll()
        try router.stub("schedule/club/2027", fixture: "schedule")
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.upcoming.last?.id, 11743)
        let query = try XCTUnwrap(router.requests(to: "schedule/club/2027").first?.url?.query(percentEncoded: false))
        XCTAssertTrue(query.contains("competition_team_id=537"), "the small per-club response: " + query)
    }
}
