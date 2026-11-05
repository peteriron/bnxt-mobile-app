@testable import BNXT
import XCTest

@MainActor
final class StandingsViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private let path = "standings/competition/25/phase/183"

    override func setUp() async throws {
        MockURLProtocol.router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "StandingsViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        MockURLProtocol.router.reset()
    }

    private func model() -> StandingsViewModel {
        let now = Date(timeIntervalSince1970: 1_793_750_400)
        return StandingsViewModel(api: BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                                     cache: ResponseCache(directory: cacheDirectory), now: { now }))
    }

    func testLoadsTheSeasonsTable() async throws {
        try MockURLProtocol.router.stub(path, fixture: "standings")
        let model = model()
        XCTAssertEqual(model.state, .idle)

        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.standings.count, 16)
        XCTAssertNil(model.cachedAt)
    }

    func testUsesTheConfiguredCompetitionAndPhase() async throws {
        try MockURLProtocol.router.stub("standings/competition/31/phase/200", fixture: "standings")
        let model = model()
        await model.load(season: Season(id: 2028, competitionId: 31, phaseIds: [200], label: "2027-28", gamesPerTeam: 30))
        XCTAssertEqual(model.standings.count, 16)
    }

    func testFailsOnlyWhenNothingIsCached() async {
        MockURLProtocol.router.fail(path)
        let model = model()
        await model.load(season: .current)
        XCTAssertEqual(model.state, .failed)
    }

    func testOfflineServesTheCacheAndSaysSo() async throws {
        try MockURLProtocol.router.stub(path, fixture: "standings")
        await model().load(season: .current) // fills the cache

        MockURLProtocol.router.reset()
        MockURLProtocol.router.fail(path)
        let model = model()
        await model.load(season: .current)

        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.standings.count, 16)
        XCTAssertNotNil(model.cachedAt)
    }

    func testTableTakesZonesFromConfigAndCountriesFromClubs() async throws {
        try MockURLProtocol.router.stub(path, fixture: "standings")
        let model = model()
        await model.load(season: .current)
        var config = try XCTUnwrap(RemoteConfig.bundled())
        config.zones = StandingsTableTests.zones

        let table = model.table(config: config, clubs: [])
        XCTAssertEqual(table.rows(for: .league).first?.zone?.id, "leader")
        XCTAssertEqual(model.table(config: nil, clubs: []).rows(for: .league).compactMap(\.zone).count, 0, "no config, no zones")
    }
}
