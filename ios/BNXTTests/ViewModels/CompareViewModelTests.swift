@testable import BNXT
import XCTest

@MainActor
final class CompareViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var router: MockURLProtocol.Router { MockURLProtocol.router }
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026
    private let teamIds = [537, 539, 541]

    override func setUp() async throws {
        router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "CompareViewModelTests-\(UUID().uuidString)")
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        router.reset()
    }

    private func model(preset: Int? = nil) -> CompareViewModel {
        let now = now
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "test"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: cacheDirectory), now: { now })
        return CompareViewModel(presetRosterId: preset, api: api)
    }

    private func stubAverages() throws {
        for id in teamIds { router.stub("competition-team/player-averages/\(id)", body: Data(#"{"data":[]}"#.utf8)) }
        try router.stub("competition-team/player-averages/537", fixture: "player_averages_537")
    }

    func testLoadsEveryClubsPlayersAndFillsTheDefaults() async throws {
        try stubAverages()
        let model = model()
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537)

        XCTAssertEqual(model.state, .loaded)
        for id in teamIds { XCTAssertEqual(router.requests(to: "competition-team/player-averages/\(id)").count, 1) }
        XCTAssertEqual(model.candidates.count, 12)
        XCTAssertEqual(model.playerA?.player.lastName, "Konieczny Jr", "Spirou's best VAL")
        XCTAssertEqual(model.playerB?.player.lastName, "Andre", "the next leader, since the leader is A")
        XCTAssertEqual(model.playerA?.teamId, 537)
    }

    func testAPlayerPagePrefillsA() async throws {
        try stubAverages()
        let model = model(preset: 11173)
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537)
        XCTAssertEqual(model.playerA?.player.lastName, "Heath")
        XCTAssertEqual(model.playerB?.player.lastName, "Konieczny Jr")
    }

    func testChoosingAndSwapping() async throws {
        try stubAverages()
        let model = model()
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537)
        model.choose(11173, for: .second)
        XCTAssertEqual(model.slotB, 11173)
        model.choose(11173, for: .first)
        XCTAssertEqual(model.slotA, 11173)
        XCTAssertEqual(model.slotB, 11181, "picking B's player for A swaps them")
    }

    func testRefreshKeepsThePicks() async throws {
        try stubAverages()
        let model = model()
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537)
        model.choose(11175, for: .first)
        model.choose(11177, for: .second)
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537, refresh: true)
        XCTAssertEqual(model.slotA, 11175)
        XCTAssertEqual(model.slotB, 11177)
    }

    func testFailsWhenEveryClubFails() async {
        for id in teamIds { router.fail("competition-team/player-averages/\(id)") }
        let model = model()
        await model.load(season: .current, teamIds: teamIds, favoriteClubId: 537)
        XCTAssertEqual(model.state, .failed)
        XCTAssertNil(model.playerA)
    }
}

/// The burst cap from docs/bnxt-api.md: no more than 4 requests in flight.
final class GatherTests: XCTestCase {
    private actor Gauge {
        var current = 0, peak = 0
        func enter() { current += 1; peak = max(peak, current) }
        func leave() { current -= 1 }
    }

    func testRunsEveryIdAtMostFourAtATimeAndDropsFailures() async {
        let gauge = Gauge()
        let results = await BNXTAPIClient.gather(Array(1...16)) { id in
            await gauge.enter()
            try? await Task.sleep(for: .milliseconds(20))
            await gauge.leave()
            if id == 7 { throw URLError(.notConnectedToInternet) }
            return id * 10
        }
        let peak = await gauge.peak
        XCTAssertEqual(results.count, 15)
        XCTAssertNil(results[7])
        XCTAssertEqual(results[16], 160)
        XCTAssertLessThanOrEqual(peak, 4)
        XCTAssertGreaterThan(peak, 1, "requests do run concurrently")
    }
}
