import XCTest

/// REQUIREMENTS §3.8: the Clubs tab and the club page, against the live API.
final class ClubsUITests: UITestCase {
    private func openClubs() {
        tab(4).tap()
        XCTAssertTrue(element("clubs.tile.CHA").waitForExistence(timeout: 10))
    }

    func testSearchFiltersTheGrid() {
        openClubs()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("zwolle")
        XCTAssertTrue(element("clubs.tile.ZWO").waitForExistence(timeout: 5))
        XCTAssertFalse(element("clubs.tile.CHA").exists)
    }

    func testClubPageShowsRosterGamesAndStats() {
        openClubs()
        element("clubs.tile.CHA").tap()
        XCTAssertTrue(element("screen.club.537").waitForExistence(timeout: 5))
        XCTAssertTrue(element("club.roster").waitForExistence(timeout: 15), "roster didn't load")
        XCTAssertTrue(element("club.facts").exists)

        let tabs = app.segmentedControls["club.tabs"]
        tabs.buttons["Games"].tap()
        XCTAssertTrue(element("club.games").waitForExistence(timeout: 5))

        tabs.buttons["Player stats"].tap()
        XCTAssertTrue(element("club.playerStats").waitForExistence(timeout: 5))
        element("club.sort.AST").tap()
        XCTAssertTrue(element("club.sort.AST").isSelected)
    }

    func testMakeMyClubChangesHome() {
        XCTAssertTrue(element("home.myClub").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.myClub").label.contains("Spirou"))

        openClubs()
        element("clubs.tile.LIE").tap()
        let make = element("club.makeMyClub")
        XCTAssertTrue(make.waitForExistence(timeout: 5))
        make.tap()
        XCTAssertTrue(element("club.isMyClub").waitForExistence(timeout: 5), "the button becomes the My club badge")
        XCTAssertFalse(make.exists)

        tab(0).tap()
        XCTAssertTrue(element("home.myClub").label.contains("Liège"), element("home.myClub").label)
    }

    func testTappingAPlayerOpensThePlayer() {
        openClubs()
        element("clubs.tile.CHA").tap()
        XCTAssertTrue(element("club.roster").waitForExistence(timeout: 15))
        let first = element("club.roster").buttons.firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'screen.player.'"))
            .firstMatch.waitForExistence(timeout: 5))
    }
}
