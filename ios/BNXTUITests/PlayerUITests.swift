import XCTest

/// REQUIREMENTS §3.8: the player page against the live API (Joshua Heath, roster 11173, Spirou).
final class PlayerUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-open", "bnxt://player/11173"] }

    func testShowsBioAveragesAndGameLog() {
        XCTAssertTrue(element("screen.player.11173").waitForExistence(timeout: 5))
        XCTAssertTrue(element("player.bio").waitForExistence(timeout: 15), "player didn't load")
        XCTAssertTrue(element("player.averages").exists, "Heath has played this season")
        XCTAssertTrue(element("player.shooting").exists)

        let log = element("player.log")
        app.swipeUp()
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        let game = log.buttons.firstMatch
        XCTAssertTrue(game.waitForExistence(timeout: 5))
        game.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'screen.game.'"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    func testClubChipOpensTheClub() {
        let chip = element("player.club")
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(element("screen.club.537").waitForExistence(timeout: 5))
    }
}
