import XCTest

/// Captures the App Store screenshots (docs/ios-playbook/04): `fastlane screenshots` runs it on the iPhone 14 Plus
/// simulator (1284×2778, a size App Store Connect accepts) and exports the attachments named `NN-Name`.
/// Excluded from routine runs with `-skip-testing:BNXTUITests/AppStoreScreenshotUITests`.
///
/// Each screen waits for its data first. Stats shows the Teams view: the Players view opens on a large photo of a
/// real player, and marketing images shouldn't feature identifiable people (playbook 04).
final class AppStoreScreenshotUITests: UITestCase {
    @MainActor
    func testCaptureScreens() {
        capture("01-Home", tab: 0, waitFor: element("home.standing"))
        capture("02-Games", tab: 1, waitFor: firstElement(withPrefix: "games.row."))
        capture("03-Standings", tab: 2, waitFor: element("standings.table"))
        capture("04-Stats", tab: 3, waitFor: firstElement(withPrefix: "stats.team.")) {
            let teams = self.app.segmentedControls["stats.segment"].buttons.element(boundBy: 1)
            if teams.waitForExistence(timeout: 10) { teams.tap() }
        }
        capture("05-Clubs", tab: 4, waitFor: firstElement(withPrefix: "clubs.tile."))
    }

    private func firstElement(withPrefix prefix: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    private func capture(_ name: String, tab index: Int, waitFor content: XCUIElement, prepare: (() -> Void)? = nil) {
        tab(index).tap()
        prepare?()
        XCTAssertTrue(content.waitForExistence(timeout: 30), "\(name): content didn't load")
        sleep(2) // logos and photos arrive after the data
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
