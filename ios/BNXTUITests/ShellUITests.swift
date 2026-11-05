import XCTest

/// REQUIREMENTS §3.1: first launch goes through onboarding, and the choice sticks.
final class OnboardingUITests: UITestCase {
    override var favoriteClub: String? { nil }

    func testPickingAClubLandsOnHomeAndPersists() {
        XCTAssertTrue(element("onboarding").waitForExistence(timeout: 5))
        element("onboarding.start").tap()

        let follow = element("onboarding.follow")
        XCTAssertTrue(follow.waitForExistence(timeout: 5))
        XCTAssertFalse(follow.isEnabled, "nothing picked yet")

        element("club.BRU").tap()
        XCTAssertTrue(element("club.BRU").isSelected)
        XCTAssertTrue(follow.isEnabled)
        follow.tap()

        let myClub = element("home.myClub")
        XCTAssertTrue(myClub.waitForExistence(timeout: 5))
        XCTAssertTrue(myClub.label.contains("Brussels"), myClub.label)
        XCTAssertFalse(element("onboarding").exists)

        // Relaunch without the reset flag: no onboarding, same club.
        app.terminate()
        app.launchArguments = ["--uitest-bundled-config"]
        app.launch()
        XCTAssertTrue(element("home.myClub").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.myClub").label.contains("Brussels"))
        XCTAssertFalse(element("onboarding").exists)
    }
}

/// REQUIREMENTS §3.8: change the club from Settings; show onboarding again.
final class SettingsUITests: UITestCase {
    func testChangingTheClubUpdatesHome() {
        XCTAssertTrue(element("home.myClub").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.myClub").label.contains("Spirou"))

        element("home.settings").tap()
        element("settings.changeClub").tap()
        let liege = element("club.LIE")
        XCTAssertTrue(liege.waitForExistence(timeout: 5))
        liege.tap()
        element("settings.done").tap()

        XCTAssertTrue(element("home.myClub").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.myClub").label.contains("Liège"), element("home.myClub").label)
    }

    func testShowOnboardingAgain() {
        XCTAssertTrue(element("home.settings").waitForExistence(timeout: 5))
        element("home.settings").tap()
        element("settings.replayOnboarding").tap()
        XCTAssertTrue(element("onboarding").waitForExistence(timeout: 5))
    }
}

/// REQUIREMENTS §7.27: deep links open the right tab and screen.
final class DeepLinkUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-open", "bnxt://club/561"] }

    func testLaunchLinkOpensTheClubInTheClubsTab() {
        XCTAssertTrue(element("screen.club.561").waitForExistence(timeout: 5))
        XCTAssertTrue(tab(4).isSelected)
    }

    func testLinkWhileRunningSwitchesTab() throws {
        XCTAssertTrue(element("screen.club.561").waitForExistence(timeout: 5))
        app.open(try XCTUnwrap(URL(string: "bnxt://game/11323")))
        XCTAssertTrue(element("screen.game.11323").waitForExistence(timeout: 5))
        XCTAssertTrue(tab(1).isSelected)

        // Tapping the selected tab again pops to its root.
        tab(1).tap()
        XCTAssertTrue(element("screen.games").waitForExistence(timeout: 5))
    }
}
