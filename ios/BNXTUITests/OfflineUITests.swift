import XCTest

/// REQUIREMENTS §4 Offline, against the real app with every request failing (`--uitest-offline`).

/// A first launch with no network and nothing cached: a clear empty state, and clubs from the bundled config.
final class OfflineFirstLaunchUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-offline", "--uitest-clear-cache"] }

    func testFirstLaunchOfflineShowsAClearEmptyStateWithRetry() {
        XCTAssertTrue(element("load.failed").waitForExistence(timeout: 30))
        XCTAssertTrue(element("load.retry").exists)
        XCTAssertFalse(element("load.cached").exists)

        tab(4).tap()
        // Offline, short names are made up from the config ("SPI"), so match any tile.
        let tiles = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'clubs.tile.'"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "the clubs list comes from the bundled config")
    }
}

/// Onboarding needs no network: the clubs to pick from are in the bundled config.
final class OfflineOnboardingUITests: UITestCase {
    override var favoriteClub: String? { nil }
    override var extraLaunchArguments: [String] { ["--uitest-offline", "--uitest-clear-cache"] }

    func testOnboardingWorksOffline() {
        let start = element("onboarding.start")
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        let tiles = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'club.'"))
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10), "clubs to pick from, from the bundled config")
        tiles.firstMatch.tap()
        XCTAssertTrue(element("onboarding.follow").isEnabled, "a club can be chosen offline")
    }
}

/// After one online launch, an offline relaunch shows the cached data and says how old it is.
final class OfflineAfterOnlineUITests: UITestCase {
    func testRelaunchOfflineShowsCachedDataWithItsAge() {
        XCTAssertTrue(element("home.standing").waitForExistence(timeout: 30), "the online launch fills the cache")
        XCTAssertFalse(element("load.cached").exists)

        app.terminate()
        app.launchArguments.append("--uitest-offline")
        app.launch()

        XCTAssertTrue(element("home.standing").waitForExistence(timeout: 30))
        XCTAssertTrue(element("load.cached").exists, "\"Offline · updated …\"")
        XCTAssertFalse(element("load.failed").exists)
    }
}
