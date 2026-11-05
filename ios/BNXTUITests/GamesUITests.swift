import XCTest

/// REQUIREMENTS §3.3: the Games tab against the live API.
final class GamesUITests: UITestCase {
    private var firstRow: XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'games.row.'")).firstMatch
    }

    func testUpcomingGameOpensItsPreview() {
        tab(1).tap()
        XCTAssertTrue(element("games.mode").waitForExistence(timeout: 5))
        guard firstRow.waitForExistence(timeout: 15) else {
            // Between seasons there may be nothing scheduled; the empty state must say so.
            XCTAssertTrue(element("games.empty").exists)
            return
        }
        firstRow.tap()
        XCTAssertTrue(element("game.tabs").waitForExistence(timeout: 15))
        XCTAssertTrue(element("game.preview").waitForExistence(timeout: 5) || element("game.boxScore").exists,
                      "upcoming games open on Preview (or Box score if one went live)")
    }

    func testResultsAndMyClubFilter() {
        tab(1).tap()
        let results = app.segmentedControls["games.mode"].buttons["Results"]
        XCTAssertTrue(results.waitForExistence(timeout: 5))
        results.tap()
        XCTAssertTrue(firstRow.waitForExistence(timeout: 15), "the slider always holds recent results")

        app.buttons["Spirou Basket"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'games.row.'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5) || element("games.empty").exists)
        for index in 0..<rows.count {
            XCTAssertTrue(rows.element(boundBy: index).label.contains("Spirou"), rows.element(boundBy: index).label)
        }
    }
}

/// REQUIREMENTS §3.4: a finished game (CHA 65–70 OOS, 23 Oct 2026) opened by deep link.
final class GameDetailUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-open", "bnxt://game/11323"] }

    func testFinishedGameTabs() {
        XCTAssertTrue(element("game.score").waitForExistence(timeout: 15), "game didn't load")
        XCTAssertTrue(element("game.quarters").exists)
        XCTAssertTrue(element("game.summary").waitForExistence(timeout: 10))

        let tabs = app.segmentedControls["game.tabs"]
        XCTAssertFalse(tabs.buttons["Preview"].exists, "no preview for a finished game")
        tabs.buttons["Box score"].tap()
        XCTAssertTrue(element("game.boxScore").waitForExistence(timeout: 5))
        element("game.boxSide.OOS").tap()
        XCTAssertTrue(element("game.boxSide.OOS").isSelected)

        tabs.buttons["Info"].tap()
        XCTAssertTrue(element("game.info.report").waitForExistence(timeout: 5))
        XCTAssertFalse(element("game.info.tickets").exists, "no tickets for a finished game")
    }

    func testTeamOpensTheClub() {
        let team = element("game.team.CHA")
        XCTAssertTrue(team.waitForExistence(timeout: 15))
        team.tap()
        XCTAssertTrue(element("screen.club.537").waitForExistence(timeout: 5))
    }
}
