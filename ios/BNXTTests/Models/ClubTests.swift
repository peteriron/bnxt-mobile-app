@testable import BNXT
import XCTest

final class ClubTests: XCTestCase {
    private func config() throws -> RemoteConfig { try XCTUnwrap(RemoteConfig.bundled()) }

    func testMergesAPITeamWithConfig() throws {
        let teams = try Fixture.list(Team.self, from: "teams")
        let clubs = Club.merge(teams: teams, config: try config())
        let spirou = try XCTUnwrap(clubs.first { $0.id == 537 })

        XCTAssertEqual(clubs.count, 16)
        XCTAssertEqual(spirou.displayName, "Spirou Basket")         // config
        XCTAssertEqual(spirou.officialName, "Val-Dieu Spirou Basket") // API
        XCTAssertEqual(spirou.city, "Charleroi")
        XCTAssertEqual(spirou.country, .belgium)
        XCTAssertNotNil(spirou.logoURL)
        XCTAssertEqual(spirou.brandColor, RGB(hex: 0xB41B1F))
        XCTAssertFalse(spirou.needsLogoPlate)
        XCTAssertEqual(clubs.map(\.displayName), clubs.map(\.displayName).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
    }

    /// Offline first launch: onboarding still has every club, grouped by country, from the config alone.
    func testConfigAloneProvidesClubs() throws {
        let clubs = Club.merge(teams: [], config: try config())

        XCTAssertEqual(clubs.count, 16)
        XCTAssertEqual(clubs.filter { $0.country == .belgium }.count, 11)
        XCTAssertEqual(clubs.filter { $0.country == .netherlands }.count, 5)
        XCTAssertTrue(clubs.allSatisfy { $0.logoURL == nil && $0.shortName.count == 3 })
        XCTAssertEqual(Set(clubs.filter(\.needsLogoPlate).map(\.id)), [561, 565, 555, 557, 539, 563])
    }

    func testWithoutConfigTheOfficialNameIsUsed() throws {
        let team = try XCTUnwrap(try Fixture.list(Team.self, from: "teams").first { $0.id == 537 })
        let club = Club(team: team, settings: nil)
        XCTAssertEqual(club.displayName, "Val-Dieu Spirou Basket")
        XCTAssertNil(club.brandColor)
        XCTAssertGreaterThanOrEqual(club.graphicColor.contrast(with: .ink), 3) // falls back to lifted violet
    }

    /// §5.1: every club colour, lifted for graphics, reaches 3:1 on ink.
    func testEveryClubGraphicColourReachesThreeToOne() throws {
        for club in Club.merge(teams: [], config: try config()) {
            XCTAssertGreaterThanOrEqual(club.graphicColor.contrast(with: .ink), 3, club.shortName)
        }
    }
}

final class ColourLiftTests: XCTestCase {
    func testDarkColoursAreLiftedToTheTarget() {
        let brussels = RGB(hex: 0x0E151B)
        let lifted = brussels.lifted(toContrast: 3, against: .ink)
        XCTAssertLessThan(brussels.contrast(with: .ink), 1.2)
        XCTAssertEqual(lifted.contrast(with: .ink), 3, accuracy: 0.02, "lifted just enough, not to white")
    }

    func testColoursAlreadyAboveTheTargetAreUnchanged() {
        let rotterdam = RGB(hex: 0x7FBE54)
        XCTAssertEqual(rotterdam.lifted(toContrast: 3, against: .ink), rotterdam)
    }

    func testMixing() {
        XCTAssertEqual(RGB(hex: 0x000000).mixed(with: .white, amount: 0.5).red, 0.5, accuracy: 0.0001)
        XCTAssertEqual(RGB(hex: 0x336699).mixed(with: .white, amount: 0), RGB(hex: 0x336699))
    }
}

@MainActor
final class FavoriteClubStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""

    override func setUp() async throws {
        suite = "FavoriteClubStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
    }

    private func club(_ id: Int, _ short: String) -> Club {
        Club(id: id, shortName: short, displayName: short, officialName: short)
    }

    func testChoosingPersistsAcrossLaunches() {
        let store = FavoriteClubStore(defaults: defaults, resetState: false)
        XCTAssertNil(store.clubId)
        store.choose(club(537, "CHA"))

        let relaunched = FavoriteClubStore(defaults: defaults, resetState: false)
        XCTAssertEqual(relaunched.saved, .init(teamId: 537, shortName: "CHA"))
    }

    func testResetStateSkipsTheLoad() {
        FavoriteClubStore(defaults: defaults, resetState: false).choose(club(537, "CHA"))
        XCTAssertNil(FavoriteClubStore(defaults: defaults, resetState: true).clubId)
    }

    func testPresetWins() {
        let store = FavoriteClubStore(defaults: defaults, resetState: true, preset: .init(teamId: 561, shortName: "BRU"))
        XCTAssertEqual(store.clubId, 561)
    }

    /// Competition-team ids change every season (§7.14): the favourite is found again by short name.
    func testResolvesByShortNameAfterASeasonChange() {
        let store = FavoriteClubStore(defaults: defaults, resetState: false)
        store.choose(club(537, "CHA"))

        let nextSeason = [club(701, "CHA"), club(702, "OOS")]
        XCTAssertEqual(store.resolve(in: nextSeason)?.id, 701)
        XCTAssertEqual(FavoriteClubStore(defaults: defaults, resetState: false).clubId, 701, "the new id is saved")
    }

    func testUnknownClubResolvesToNil() {
        let store = FavoriteClubStore(defaults: defaults, resetState: false)
        store.choose(club(537, "CHA"))
        XCTAssertNil(store.resolve(in: [club(702, "OOS")]))
        store.clear()
        XCTAssertNil(FavoriteClubStore(defaults: defaults, resetState: false).saved)
    }
}

@MainActor
final class AppModelTests: XCTestCase {
    override func setUp() async throws { MockURLProtocol.router.reset() }
    override func tearDown() async throws { MockURLProtocol.router.reset() }

    private func model() throws -> AppModel {
        let config = try XCTUnwrap(RemoteConfig.bundled())
        let directory = FileManager.default.temporaryDirectory.appending(path: "AppModelTests-\(UUID().uuidString)")
        let api = BNXTAPIClient(configuration: APIConfiguration(apiKey: "k"), session: MockURLProtocol.session(),
                                cache: ResponseCache(directory: directory))
        let configClient = RemoteConfigClient(session: MockURLProtocol.session(), cache: nil, bundled: { config }, bundledOnly: true)
        return AppModel(api: api, configClient: configClient, config: config)
    }

    func testStartsWithConfigClubsBeforeLoading() throws {
        let model = try model()
        XCTAssertEqual(model.clubs.count, 16)
        XCTAssertEqual(model.clubsSource, .bundled)
        XCTAssertEqual(model.clubsByCountry.map(\.country), [.belgium, .netherlands])
    }

    func testLoadMergesAPITeams() async throws {
        try MockURLProtocol.router.stub("competition-team/all", fixture: "teams")
        let model = try model()

        await model.load()

        XCTAssertEqual(model.clubsSource, .network)
        XCTAssertNotNil(model.club(id: 537)?.logoURL)
        XCTAssertEqual(model.club(id: 537)?.displayName, "Spirou Basket")
    }

    func testAPIFailureKeepsConfigClubs() async throws {
        MockURLProtocol.router.fail("competition-team/all")
        let model = try model()

        await model.load()

        XCTAssertEqual(model.clubs.count, 16)
        XCTAssertEqual(model.clubsSource, .bundled)
    }
}
