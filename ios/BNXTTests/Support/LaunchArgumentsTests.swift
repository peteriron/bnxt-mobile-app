@testable import BNXT
import XCTest

final class LaunchArgumentsTests: XCTestCase {
    func testDetectsResetFlag() {
        XCTAssertTrue(LaunchArguments.resetState(["BNXT", "--uitest-reset-state"]))
        XCTAssertFalse(LaunchArguments.resetState(["BNXT"]))
    }

    func testDetectsOfflineAndClearCacheFlags() {
        XCTAssertTrue(LaunchArguments.offline(["BNXT", "--uitest-offline"]))
        XCTAssertFalse(LaunchArguments.offline(["BNXT"]))
        XCTAssertTrue(LaunchArguments.clearCache(["BNXT", "--uitest-clear-cache"]))
        XCTAssertFalse(LaunchArguments.clearCache(["BNXT", "--uitest-offline"]))
    }
}
