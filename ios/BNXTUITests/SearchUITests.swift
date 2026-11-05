import XCTest

/// REQUIREMENTS §3.8: Search from Home's header, against the live API.
final class SearchUITests: UITestCase {
    private func openSearch() {
        let button = element("home.search")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(element("screen.search").waitForExistence(timeout: 5))
    }

    func testSuggestionsWhenEmpty() {
        openSearch()
        let mine = element("search.suggestion.club")
        XCTAssertTrue(mine.waitForExistence(timeout: 5))
        XCTAssertTrue(mine.label.contains("Spirou"), mine.label)
    }

    func testFindsAPlayerAndOpensTheirPage() {
        openSearch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Heath\n") // Return dismisses the keyboard before the next tap
        let heath = element("search.player.11173")
        XCTAssertTrue(heath.waitForExistence(timeout: 20), "rosters didn't load")
        heath.tap()
        XCTAssertTrue(element("screen.player.11173").waitForExistence(timeout: 5))
    }

    func testFindsAClubFromTheFirstCharacters() {
        openSearch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("zwo\n")
        let club = element("search.club.ZWO")
        XCTAssertTrue(club.waitForExistence(timeout: 5))
        club.tap()
        XCTAssertTrue(element("screen.club.549").waitForExistence(timeout: 5))
    }

    func testNoResults() {
        openSearch()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("qqqqzz")
        XCTAssertTrue(element("search.empty").waitForExistence(timeout: 20))
    }
}
