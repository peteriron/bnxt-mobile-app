import XCTest

/// Captures one screenshot per screen for review and, later, the App Store
/// (docs/ios-playbook/04). Excluded from routine runs with
/// `-skip-testing:BNXTUITests/AppStoreScreenshotUITests`.
///
/// For now it attaches screenshots to the .xcresult (export with
/// `xcrun xcresulttool export attachments`). When fastlane `snapshot` is set up,
/// each attachment becomes a `snapshot("NN-Name")` call.
final class AppStoreScreenshotUITests: UITestCase {
    @MainActor
    func testCaptureScreens() {
        let names = ["01-Home", "02-Games", "03-Standings", "04-Stats", "05-Clubs"]
        for (index, name) in names.enumerated() {
            tab(index).tap()
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
