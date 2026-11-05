import XCTest

/// Base class for UI tests: launches the real app from a known-empty state.
/// Rules (ios/SETUP.md): query content by accessibilityIdentifier, the tab bar by index.
@MainActor
class UITestCase: XCTestCase {
    var app: XCUIApplication!

    /// Extra launch arguments for a whole test class (e.g. a pinned version policy).
    var extraLaunchArguments: [String] { [] }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitest-reset-state"] + extraLaunchArguments
        app.launch()
    }

    /// Tab bar buttons in `AppTab` order: 0 Home, 1 Games, 2 Standings, 3 Stats, 4 Clubs.
    func tab(_ index: Int) -> XCUIElement {
        app.tabBars.buttons.element(boundBy: index)
    }

    func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    func screen(_ id: String) -> XCUIElement {
        element(id)
    }
}
