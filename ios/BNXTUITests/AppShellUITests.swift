import XCTest

/// The app shell: every tab exists and opens its own screen (REQUIREMENTS.md §7.2).
final class AppShellUITests: UITestCase {
    @MainActor
    func testAllFiveTabsOpenTheirScreen() {
        let screens = ["screen.home", "screen.games", "screen.standings", "screen.stats", "screen.clubs"]
        XCTAssertEqual(app.tabBars.buttons.count, screens.count)

        for (index, id) in screens.enumerated() {
            tab(index).tap()
            XCTAssertTrue(screen(id).waitForExistence(timeout: 5), "Tab \(index) did not open \(id)")
        }
    }
}
