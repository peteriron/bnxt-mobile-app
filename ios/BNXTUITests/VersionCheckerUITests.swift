import XCTest

/// REQUIREMENTS §3.9 on screen, with the policy pinned by `--uitest-version-policy` (Debug builds only).
final class UpdateRequiredUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-version-policy", "required"] }

    func testRequiredUpdateBlocksTheApp() {
        XCTAssertTrue(element("update.required").waitForExistence(timeout: 5))
        XCTAssertTrue(element("update.required.button").exists)
        // Nothing behind it is reachable.
        XCTAssertFalse(tab(1).isHittable)
    }
}

final class UpdateAvailableUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-version-policy", "available"] }

    func testBannerShowsOnHomeAndStaysDismissedAfterRelaunch() {
        let banner = element("update.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertFalse(element("update.required").exists)

        // Only on Home.
        tab(1).tap()
        XCTAssertFalse(banner.exists)
        tab(0).tap()
        XCTAssertTrue(banner.waitForExistence(timeout: 5))

        element("update.banner.dismiss").tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5))

        // Relaunch without the reset flag: the dismissal persisted.
        app.terminate()
        app.launchArguments = ["--uitest-version-policy", "available"]
        app.launch()
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element("update.banner").exists)
    }
}

final class UpToDateUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-version-policy", "current"] }

    func testNoBannerOrBlockWhenUpToDate() {
        XCTAssertTrue(element("screen.home").waitForExistence(timeout: 5))
        XCTAssertFalse(element("update.banner").exists)
        XCTAssertFalse(element("update.required").exists)
    }
}
