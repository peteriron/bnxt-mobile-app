import XCTest

/// Phase 4 (§3.4, §7.4): a live game opens on Plays with the feed's clock. Runs only while a game is live
/// (game nights); skipped otherwise, so it never fails for lack of a game.
final class LiveGameUITests: UITestCase {
    func testALiveGameOpensOnPlaysAndHasABoxScore() throws {
        tab(1).tap()
        let anyRow = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'games.row.'")).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 15) || element("games.empty").exists)
        let live = element("games.section.live")
        guard live.exists else { throw XCTSkip("No game is live right now") }

        live.buttons.firstMatch.tap()
        XCTAssertTrue(element("game.tabs").waitForExistence(timeout: 15))
        XCTAssertTrue(app.segmentedControls["game.tabs"].buttons.element(boundBy: 0).isSelected, "Plays is the first tab")
        XCTAssertTrue(element("game.plays").waitForExistence(timeout: 15) || element("game.noPlays").exists)

        // The box score: the feed's while BNXT's is empty, so it has lines from the first poll.
        app.segmentedControls["game.tabs"].buttons["Box score"].tap()
        XCTAssertTrue(element("game.boxScore").waitForExistence(timeout: 15) || element("game.noBoxScore").exists)
    }
}
