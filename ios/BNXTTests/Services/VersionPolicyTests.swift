@testable import BNXT
import XCTest

final class SemanticVersionTests: XCTestCase {
    func testParsesShortAndPreReleaseForms() {
        let cases = [("1", "1.0.0"), ("1.2", "1.2.0"), ("1.2.3", "1.2.3"), (" 2.0.1 ", "2.0.1"), ("1.4.0-beta.2", "1.4.0")]
        for (input, expected) in cases {
            XCTAssertEqual(SemanticVersion(input)?.description, expected, input)
        }
    }

    func testRejectsMalformedVersions() {
        for input in ["", "a.b", "1.2.3.4", "-1.0", "1..2", "1.2.", "v1.2", "1.٢"] {
            XCTAssertNil(SemanticVersion(input), input)
        }
    }

    func testComparesNumericallyNotLexically() throws {
        func version(_ string: String) throws -> SemanticVersion { try XCTUnwrap(SemanticVersion(string)) }
        XCTAssertGreaterThan(try version("1.10.0"), try version("1.9.9"))
        XCTAssertGreaterThan(try version("2.0"), try version("1.99.99"))
        XCTAssertEqual(try version("1.0"), try version("1.0.0"))
    }
}

final class VersionEvaluatorTests: XCTestCase {
    private func policy(latest: String? = "1.2.0", minimum: String? = "1.0.3", blocked: [String] = []) -> VersionPolicy {
        VersionPolicy(latestVersion: latest, minimumVersion: minimum, blockedVersions: blocked)
    }

    private func evaluate(_ installed: String, _ policy: VersionPolicy?, minimumDataSchema: Int = 1) -> UpdateStatus {
        VersionEvaluator.evaluate(installed: installed, policy: policy, minimumDataSchema: minimumDataSchema, dataSchema: 1)
    }

    func testUpToDateAtOrAboveLatest() {
        XCTAssertEqual(evaluate("1.2.0", policy()), .upToDate)
        XCTAssertEqual(evaluate("1.3.0", policy()), .upToDate)
    }

    func testUpdateAvailableBelowLatest() throws {
        XCTAssertEqual(evaluate("1.1.5", policy()), .updateAvailable(latest: try XCTUnwrap(SemanticVersion("1.2.0"))))
    }

    /// The minimum itself is still allowed.
    func testMinimumVersionIsAllowed() throws {
        XCTAssertEqual(evaluate("1.0.3", policy()), .updateAvailable(latest: try XCTUnwrap(SemanticVersion("1.2.0"))))
    }

    func testRequiredBelowMinimum() throws {
        XCTAssertEqual(evaluate("1.0.2", policy()), .updateRequired(reason: .belowMinimum(try XCTUnwrap(SemanticVersion("1.0.3")))))
    }

    func testBlockedVersionIsRequiredEvenAboveMinimum() {
        XCTAssertEqual(evaluate("1.1.0", policy(blocked: ["1.1"])), .updateRequired(reason: .blocked))
    }

    func testNewerDataSchemaForcesAnUpdate() {
        XCTAssertEqual(evaluate("9.9.9", policy(), minimumDataSchema: 2), .updateRequired(reason: .dataSchemaTooOld))
    }

    func testNoPolicyOrUnparsableInstalledVersionIsUnknown() {
        XCTAssertEqual(evaluate("1.0.0", nil), .unknown)
        XCTAssertEqual(evaluate("dev", policy()), .unknown)
    }

    func testEmptyPolicyMeansUpToDate() {
        XCTAssertEqual(evaluate("0.1.0", policy(latest: nil, minimum: nil)), .upToDate)
    }

    /// A typo in the config must never lock users out: an unsound policy is ignored.
    func testUnsoundPolicyIsIgnored() {
        XCTAssertEqual(evaluate("1.0.0", policy(latest: "1.0.0", minimum: "2.0.0")), .unknown) // minimum above latest
        XCTAssertEqual(evaluate("1.0.0", policy(latest: "1.0.0", minimum: "two")), .unknown)
        XCTAssertEqual(evaluate("1.0.0", policy(blocked: ["1.0.0", "x"])), .unknown)
        var insecure = policy(latest: "1.0.0", minimum: "1.0.0")
        insecure.storeURL = URL(string: "http://apps.apple.com/app/id1")
        XCTAssertEqual(evaluate("0.9.0", insecure), .unknown)
    }

    func testProblemNamesTheIssue() {
        XCTAssertNil(policy().problem)
        XCTAssertEqual(policy(latest: "1.0.0", minimum: "2.0.0").problem, "minimumVersion 2.0.0 is above latestVersion 1.0.0")
    }

    func testMessageFallsBackToEnglish() {
        let policy = VersionPolicy(message: ["en": "Update", "nl": "Bijwerken"])
        XCTAssertEqual(policy.message(for: "nl"), "Bijwerken")
        XCTAssertEqual(policy.message(for: "fr"), "Update")
        XCTAssertNil(VersionPolicy().message(for: "en"))
    }
}
