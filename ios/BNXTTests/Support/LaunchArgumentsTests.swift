@testable import BNXT
import XCTest

final class LaunchArgumentsTests: XCTestCase {
    func testDetectsResetFlag() {
        XCTAssertTrue(LaunchArguments.resetState(["BNXT", "--uitest-reset-state"]))
        XCTAssertFalse(LaunchArguments.resetState(["BNXT"]))
    }
}
