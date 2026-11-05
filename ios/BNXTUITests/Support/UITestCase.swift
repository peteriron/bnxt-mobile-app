import XCTest

/// Base class for UI tests: launches the real app from a known state.
/// - `--uitest-reset-state`: stores skip loading persisted state.
/// - `--uitest-bundled-config`: the app uses the config bundled in this build, not whatever is published (§7.24).
/// - `--uitest-favorite-club`: a favourite is preset so tests land on Home; onboarding tests set `favoriteClub` to nil.
/// Rules (ios/SETUP.md): query content by accessibilityIdentifier, the tab bar by index.
@MainActor
class UITestCase: XCTestCase {
    var app: XCUIApplication!

    /// The preset favourite ("id:shortName"), or nil to start in onboarding.
    var favoriteClub: String? { "537:CHA" }

    /// Extra launch arguments for a whole test class (e.g. a pinned version policy).
    var extraLaunchArguments: [String] { [] }

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitest-reset-state", "--uitest-bundled-config"] + extraLaunchArguments
        if let favoriteClub { app.launchArguments += ["--uitest-favorite-club", favoriteClub] }
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
