@testable import BNXT
import XCTest

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026
    private let teamIds = [537, 539]

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "SearchViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func model() -> SearchViewModel {
        let now = now
        return SearchViewModel(api: BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                                  cache: ResponseCache(directory: cacheDirectory), now: { now }))
    }

    private func stubAll() throws {
        try router.stub("roster/team-players/537", fixture: "roster_537")
        router.stub("roster/team-players/539", body: Data(#"{"data":[]}"#.utf8))
        try router.stub("player/average-rankings/25", fixture: "player_leaders")
    }

    func testLoadsRostersAndSuggestions() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current, teamIds: teamIds)
        XCTAssertEqual(model.state, .loaded)
        XCTAssertEqual(model.players.count, 13)
        XCTAssertEqual(model.suggestedPlayers.first?.rosterId, 11453)
        XCTAssertFalse(model.playersUnavailable)
    }

    /// Typing filters on device: no request per keystroke.
    func testTypingMakesNoRequests() async throws {
        try stubAll()
        let model = model()
        await model.load(season: .current, teamIds: teamIds)
        let before = router.requests.count
        for prefix in ["h", "he", "hea", "heat", "heath"] { model.query = prefix; _ = model.playerResults }
        XCTAssertEqual(model.playerResults.map(\.rosterId), [11173])
        XCTAssertEqual(router.requests.count, before)
        XCTAssertTrue(model.isSearching)
    }

    func testRostersAreReusedWithinTheHour() async throws {
        try stubAll()
        await model().load(season: .current, teamIds: teamIds)
        await model().load(season: .current, teamIds: teamIds)
        XCTAssertEqual(router.requests(to: "roster/team-players/537").count, 1)
    }

    func testWithoutRostersClubsStillWork() async {
        router.fail("roster/team-players/537")
        router.fail("roster/team-players/539")
        let model = model()
        await model.load(season: .current, teamIds: teamIds)
        XCTAssertEqual(model.state, .loaded, "clubs come from the app's own list")
        XCTAssertTrue(model.playersUnavailable)
        model.query = "lie"
        XCTAssertEqual(model.clubResults([Club(id: 567, shortName: "LIE", displayName: "Liège Basket", officialName: "Liège")]).count, 1)
    }
}
