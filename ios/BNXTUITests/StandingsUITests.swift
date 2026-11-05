import XCTest

/// REQUIREMENTS §3.5: the Standings tab against the live API.
final class StandingsUITests: UITestCase {
    private func openStandings() {
        tab(2).tap()
        XCTAssertTrue(element("standings.table").waitForExistence(timeout: 15), "standings didn't load")
    }

    private func segment(_ title: String) -> XCUIElement {
        app.segmentedControls["standings.segment"].buttons[title]
    }

    func testSwitchingViewsShowsTheCutLineAndBrackets() {
        openStandings()
        XCTAssertTrue(element("standings.legend").exists)
        XCTAssertFalse(element("standings.cutLine").exists, "the league table has no cut line")

        segment("Belgium").tap()
        XCTAssertTrue(element("standings.cutLine").waitForExistence(timeout: 5))
        XCTAssertTrue(element("standings.row.CHA").exists)
        XCTAssertFalse(element("standings.row.LEI").exists, "Dutch club in the Belgian table")

        segment("Netherlands").tap()
        XCTAssertTrue(element("standings.row.LEI").waitForExistence(timeout: 5))
        XCTAssertFalse(element("standings.row.CHA").exists)

        segment("Playoffs").tap()
        XCTAssertTrue(element("standings.bracket.BE").waitForExistence(timeout: 5))
        XCTAssertTrue(element("standings.bracket.NL").exists)
    }

    func testTappingARowOpensTheClub() {
        openStandings()
        let row = element("standings.row.CHA")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element("screen.club.537").waitForExistence(timeout: 5))
    }
}
