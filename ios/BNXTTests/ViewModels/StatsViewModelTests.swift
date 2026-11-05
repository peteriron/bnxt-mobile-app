@testable import BNXT
import XCTest

@MainActor
final class StatsViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026
    /// The 16 clubs of 2026-27 (docs/bnxt-api.md).
    private let teamIds = [537, 539, 541, 543, 545, 547, 549, 551, 553, 555, 557, 559, 561, 563, 565, 567]

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "StatsViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func api() -> BNXTAPIClient {
        let now = now
        return BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                             cache: ResponseCache(directory: cacheDirectory), now: { now })
    }

    private static let emptyList = Data(#"{"data":[]}"#.utf8)

    private func stubTeams() throws {
        for id in teamIds { router.stub("competition-team/statistics-by-game/total/\(id)", body: Self.emptyList) }
        try router.stub("competition-team/statistics-by-game/total/537", fixture: "team_games_537")
    }

    // MARK: Players

    func testLoadsLeadersForThePlayersView() async throws {
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
        let model = StatsViewModel(api: api())
        await model.loadIfNeeded(season: .current, teamIds: teamIds)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.playerRows.first?.entry.rosterId, 11453)
        XCTAssertTrue(router.requests.allSatisfy { !MockURLProtocol.Router.apiPath(of: $0).contains("statistics-by-game") },
                      "Teams costs 16 requests; it waits until it's shown")

        model.playerCategory = .assists
        XCTAssertEqual(model.playerRows.first?.entry.rosterId, model.leaders?[.assists].first?.rosterId)
    }

    func testLeadersAreReusedWithinTheHourButRefreshAsksAgain() async throws {
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
        let first = StatsViewModel(api: api())
        await first.loadIfNeeded(season: .current, teamIds: teamIds)
        let second = StatsViewModel(api: api())
        await second.loadIfNeeded(season: .current, teamIds: teamIds)
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").count, 1, "the second visit used the stored copy")

        await second.refresh(season: .current, teamIds: teamIds)
        XCTAssertEqual(router.requests(to: "player/average-rankings/25").count, 2)
    }

    func testFailsWithNothingToShow() async {
        router.fail("player/average-rankings/25")
        let model = StatsViewModel(api: api())
        await model.loadIfNeeded(season: .current, teamIds: teamIds)
        XCTAssertEqual(model.state, .failed)
    }

    // MARK: Teams

    func testTeamsLoadEveryClubAndRankThem() async throws {
        try stubTeams()
        let model = StatsViewModel(api: api())
        model.mode = .teams
        await model.loadIfNeeded(season: .current, teamIds: teamIds)

        XCTAssertEqual(model.state, .loaded)
        for id in teamIds {
            XCTAssertEqual(router.requests(to: "competition-team/statistics-by-game/total/\(id)").count, 1, "club \(id)")
        }
        XCTAssertEqual(model.teamRows.map(\.teamId), [537], "clubs without finished games are left out")
        XCTAssertEqual(try XCTUnwrap(model.teamRows.first?.value), 79.8, accuracy: 0.001)
        XCTAssertNil(model.cachedAt)
    }

    func testOneFailingClubDoesNotFailTheTable() async throws {
        try stubTeams()
        router.fail("competition-team/statistics-by-game/total/539")
        let model = StatsViewModel(api: api())
        model.mode = .teams
        await model.loadIfNeeded(season: .current, teamIds: teamIds)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.teamRows.count, 1)
    }

    func testTeamsFailWhenEveryClubFails() async {
        for id in teamIds { router.fail("competition-team/statistics-by-game/total/\(id)") }
        let model = StatsViewModel(api: api())
        model.mode = .teams
        await model.loadIfNeeded(season: .current, teamIds: teamIds)
        XCTAssertEqual(model.state, .failed)
    }

    func testTeamsOfflineServeTheCache() async throws {
        try stubTeams()
        let online = StatsViewModel(api: api())
        online.mode = .teams
        await online.loadIfNeeded(season: .current, teamIds: teamIds)

        for id in teamIds { router.fail("competition-team/statistics-by-game/total/\(id)") }
        let offline = StatsViewModel(api: api())
        offline.mode = .teams
        await offline.refresh(season: .current, teamIds: teamIds)
        XCTAssertEqual(offline.state, .loaded)
        XCTAssertEqual(offline.teamRows.map(\.teamId), [537])
        XCTAssertNotNil(offline.cachedAt)
    }
}
