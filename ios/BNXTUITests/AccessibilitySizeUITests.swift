import XCTest

/// REQUIREMENTS §4 Accessibility: at accessibility text sizes side-by-side layouts stack instead of truncating.
/// Home's next game and last result are the canary: `AdaptiveStack` drives every such layout.
final class AccessibilitySizeUITests: UITestCase {
    override var extraLaunchArguments: [String] {
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    }

    func testHomeCardsStackAtTheLargestTextSize() {
        let next = element("home.next"), last = element("home.last")
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(next.frame.maxY, last.frame.minY + 1, "next game above last result, not beside it")
    }
}

final class RegularSizeUITests: UITestCase {
    override var extraLaunchArguments: [String] {
        ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    }

    func testHomeCardsSitSideBySideAtTheDefaultTextSize() {
        let next = element("home.next"), last = element("home.last")
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        XCTAssertEqual(next.frame.minY, last.frame.minY, accuracy: 1, "side by side")
        XCTAssertLessThan(next.frame.maxX, last.frame.minX + 1)
    }
}
