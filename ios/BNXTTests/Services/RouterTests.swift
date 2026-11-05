@testable import BNXT
import XCTest

final class DeepLinkTests: XCTestCase {
    private func parse(_ string: String) -> (tab: AppTab, route: Route)? {
        URL(string: string).flatMap(DeepLink.parse)
    }

    func testParsesClubGameAndPlayerLinks() {
        XCTAssertEqual(parse("bnxt://club/537")?.tab, .clubs)
        XCTAssertEqual(parse("bnxt://club/537")?.route, .club(id: 537))
        XCTAssertEqual(parse("bnxt://game/11323")?.tab, .games)
        XCTAssertEqual(parse("bnxt://game/11323")?.route, .game(id: 11323))
        XCTAssertEqual(parse("BNXT://Player/11173")?.route, .player(rosterId: 11173))
    }

    func testRejectsOtherLinks() {
        for link in ["https://bnxtleague.com/club/537", "bnxt://club", "bnxt://club/abc", "bnxt://club/0", "bnxt://club/537/extra",
                     "bnxt://team/537", "otherapp://club/537"] {
            XCTAssertNil(parse(link), link)
        }
    }

    func testRoundTripsRoutes() throws {
        for route in [Route.club(id: 537), .game(id: 11323), .player(rosterId: 11173)] {
            let url = try XCTUnwrap(DeepLink.url(for: route))
            XCTAssertEqual(DeepLink.parse(url)?.route, route)
        }
    }
}

@MainActor
final class RouterTests: XCTestCase {
    func testOpeningALinkSelectsItsTabWithAFreshStack() throws {
        let router = Router()
        router.selectedTab = .games
        router.push(.game(id: 1))

        XCTAssertTrue(router.open(try XCTUnwrap(URL(string: "bnxt://club/561"))))

        XCTAssertEqual(router.selectedTab, .clubs)
        XCTAssertEqual(router.path(for: .clubs), [.club(id: 561)])
        XCTAssertEqual(router.path(for: .games), [.game(id: 1)], "other tabs keep their stack")
    }

    /// A link replaces whatever the target tab had stacked, so Back returns to that tab's root.
    func testLinkReplacesAnExistingStackOnItsTab() throws {
        let router = Router()
        router.selectedTab = .clubs
        router.push(.club(id: 537))
        router.push(.player(rosterId: 11173))

        router.open(try XCTUnwrap(URL(string: "bnxt://club/561")))

        XCTAssertEqual(router.path(for: .clubs), [.club(id: 561)])
    }

    func testUnknownLinkChangesNothing() throws {
        let router = Router()
        XCTAssertFalse(router.open(try XCTUnwrap(URL(string: "bnxt://nope/1"))))
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertTrue(router.paths.isEmpty)
    }

    func testPushGoesOnTheCurrentTab() {
        let router = Router()
        router.push(.club(id: 537))
        router.push(.player(rosterId: 11173))
        XCTAssertEqual(router.path(for: .home), [.club(id: 537), .player(rosterId: 11173)])
    }

    func testReselectingTheCurrentTabPopsToRoot() {
        let router = Router()
        router.push(.club(id: 537))
        router.reselect(.games)
        XCTAssertEqual(router.path(for: .home).count, 1, "switching tabs keeps the stack")
        router.reselect(.home)
        router.reselect(.home)
        XCTAssertEqual(router.path(for: .home), [])
    }

    func testLaunchArgumentsForUITests() {
        XCTAssertEqual(LaunchArguments.presetFavoriteClub(["--uitest-favorite-club", "537:CHA"]), .init(teamId: 537, shortName: "CHA"))
        XCTAssertNil(LaunchArguments.presetFavoriteClub(["--uitest-favorite-club", "537"]))
        XCTAssertEqual(LaunchArguments.openURL(["--uitest-open", "bnxt://club/1"])?.absoluteString, "bnxt://club/1")
        XCTAssertTrue(LaunchArguments.bundledConfigOnly(["--uitest-bundled-config"]))
        XCTAssertFalse(LaunchArguments.bundledConfigOnly([]))
    }
}
