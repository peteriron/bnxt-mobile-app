import XCTest

/// REQUIREMENTS §3.2: the club-centric Home against the live API, with Spirou (537) as the favourite.
final class HomeUITests: UITestCase {
    private func waitForHome() {
        XCTAssertTrue(element("home.myClub").waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.standing").waitForExistence(timeout: 15), "home didn't load")
    }

    func testShowsResultStandingLeadersAndTheLeague() {
        waitForHome()
        XCTAssertTrue(element("home.last").exists || element("home.next").exists, "a last result or a next game")
        XCTAssertTrue(element("home.standing").label.contains("in the league"), element("home.standing").label)
        XCTAssertTrue(element("home.clubLeaders").exists, "Spirou have played this season")
        app.swipeUp()
        XCTAssertTrue(element("home.around").waitForExistence(timeout: 5))
        // The leaders response is slow (~10 s); it fills in after the rest.
        XCTAssertTrue(element("home.leagueLeaders").waitForExistence(timeout: 30))
    }

    func testStandingCardOpensTheStandingsTab() {
        waitForHome()
        element("home.standing").tap()
        XCTAssertTrue(tab(2).isSelected)
        XCTAssertTrue(element("screen.standings").waitForExistence(timeout: 5))
    }

    func testClubLeaderOpensThePlayer() {
        waitForHome()
        let leader = element("home.clubLeader.PTS")
        XCTAssertTrue(leader.waitForExistence(timeout: 5))
        leader.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'screen.player.'"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    func testAResultOpensTheGame() {
        waitForHome()
        app.swipeUp()
        let result = element("home.around").buttons.firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'screen.game.'"))
            .firstMatch.waitForExistence(timeout: 5))
    }
}
