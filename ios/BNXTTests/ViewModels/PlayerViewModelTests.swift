@testable import BNXT
import XCTest

@MainActor
final class PlayerViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "PlayerViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func model(rosterId: Int = 11173) -> PlayerViewModel {
        let now = now
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: cacheDirectory), now: { now })
        return PlayerViewModel(rosterId: rosterId, api: api, now: { now })
    }

    private func stubAll() throws {
        try router.stub("roster/find/11173", fixture: "roster_entry_11173")
        try router.stub("boxscore/player/season-games/11173", fixture: "player_game_log_11173")
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
    }

    func testLoadsBioSeasonAndRanks() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.entry?.player.lastName, "Heath")
        XCTAssertEqual(model.age, 31, "born 28 Dec 1994; the birth date itself is never shown (§7.16)")
        XCTAssertEqual(model.teamId, 537)
        XCTAssertEqual(model.jersey, "3")
        XCTAssertEqual(model.season?.games, 5)
        XCTAssertEqual(model.log.count, 5)
        XCTAssertEqual(model.rank(.assists), 1)
        XCTAssertNil(model.rank(.points))
        XCTAssertNil(model.cachedAt)
    }

    /// The API answers an unknown roster id with HTTP 200 and an empty list; the bio still shows.
    func testPlayerWithoutGamesShowsTheBioOnly() async throws {
        try stubAll()
        try router.stub("boxscore/player/season-games/11173", fixture: "player_game_log_unknown")
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.entry)
        XCTAssertNil(model.season)
        XCTAssertTrue(model.log.isEmpty)
    }

    func testMissingLeadersOnlyDropTheBadges() async throws {
        try stubAll()
        router.fail("player/average-rankings/25")
        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.season)
        XCTAssertNil(model.rank(.assists))
    }

    func testFailsWhenNeitherBioNorGamesLoad() async {
        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.state, .failed)
    }

    func testOfflineServesTheCache() async throws {
        try stubAll()
        await model().load(season: .current)
        router.reset()
        ["roster/find/11173", "boxscore/player/season-games/11173", "player/average-rankings/25"].forEach { router.fail($0) }

        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertNotNil(model.cachedAt)
        XCTAssertEqual(model.season?.games, 5)
    }
}
