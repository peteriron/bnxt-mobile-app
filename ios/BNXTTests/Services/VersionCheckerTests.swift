@testable import BNXT
import XCTest

@MainActor
final class VersionCheckerTests: XCTestCase {
    /// Counts calls and returns whatever `snapshot` holds at the time.
    final class FakeSource: VersionPolicySource, @unchecked Sendable {
        private let lock = NSLock()
        private var _snapshot: PolicySnapshot?
        private var _calls = 0
        var snapshot: PolicySnapshot? {
            get { lock.withLock { _snapshot } }
            set { lock.withLock { _snapshot = newValue } }
        }
        var calls: Int { lock.withLock { _calls } }

        init(_ snapshot: PolicySnapshot?) { _snapshot = snapshot }

        func currentPolicy() async -> PolicySnapshot? {
            lock.withLock { _calls += 1; return _snapshot }
        }
    }

    private var defaults: UserDefaults!
    private var suiteName = ""
    private var clock = Date(timeIntervalSince1970: 0)

    override func setUp() async throws {
        suiteName = "VersionCheckerTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        clock = Date(timeIntervalSince1970: 0)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func snapshot(latest: String? = "1.2.0", minimum: String? = "1.0.0") -> PolicySnapshot {
        PolicySnapshot(policy: VersionPolicy(latestVersion: latest, minimumVersion: minimum))
    }

    private func checker(_ source: FakeSource, installed: String = "1.1.0", resetState: Bool = false) -> VersionChecker {
        VersionChecker(source: source, installedVersion: installed, defaults: defaults, resetState: resetState,
                       minimumInterval: 6 * 3600, now: { [unowned self] in self.clock })
    }

    func testStartsUnknownAndEvaluatesOnCheck() async throws {
        let checker = checker(FakeSource(snapshot()))
        XCTAssertEqual(checker.status, .unknown)

        await checker.check()

        XCTAssertEqual(checker.status, .updateAvailable(latest: try XCTUnwrap(SemanticVersion("1.2.0"))))
        XCTAssertEqual(checker.policy?.latestVersion, "1.2.0")
    }

    /// A network failure (no policy at all) never blocks, and never wipes a known status.
    func testFailedCheckKeepsThePreviousStatus() async {
        let source = FakeSource(nil)
        let checker = checker(source)
        await checker.check()
        XCTAssertEqual(checker.status, .unknown)
        XCTAssertFalse(checker.status.isRequired)

        source.snapshot = snapshot(latest: "1.1.0", minimum: "1.1.0")
        await checker.check(force: true)
        XCTAssertEqual(checker.status, .upToDate)

        source.snapshot = nil
        await checker.check(force: true)
        XCTAssertEqual(checker.status, .upToDate)
    }

    func testChecksAtMostEverySixHoursUnlessForced() async {
        let source = FakeSource(snapshot())
        let checker = checker(source)

        await checker.check()
        clock += 60
        await checker.check()
        XCTAssertEqual(source.calls, 1, "a second check within 6 h is skipped")

        clock += 6 * 3600
        await checker.check()
        XCTAssertEqual(source.calls, 2, "the interval elapsed")

        await checker.check(force: true)
        XCTAssertEqual(source.calls, 3, "force bypasses the interval")
    }

    func testPolicyChangeToRequiredIsPickedUp() async {
        let source = FakeSource(snapshot())
        let checker = checker(source)
        await checker.check()

        source.snapshot = snapshot(latest: "2.0.0", minimum: "2.0.0")
        clock += 7 * 3600
        await checker.check()

        XCTAssertTrue(checker.status.isRequired)
    }

    func testDismissedBannerStaysDismissedUntilANewerVersion() async {
        let source = FakeSource(snapshot(latest: "1.2.0"))
        let first = checker(source)
        await first.check()
        XCTAssertTrue(first.showsUpdateBanner)

        first.dismissBanner()
        XCTAssertFalse(first.showsUpdateBanner)

        // Persisted across launches…
        let relaunched = checker(source)
        await relaunched.check()
        XCTAssertFalse(relaunched.showsUpdateBanner)

        // …until a newer latest version appears.
        source.snapshot = snapshot(latest: "1.3.0")
        await relaunched.check(force: true)
        XCTAssertTrue(relaunched.showsUpdateBanner)
    }

    func testResetStateIgnoresTheDismissedVersion() async {
        defaults.set("1.2.0", forKey: VersionChecker.dismissedVersionKey)
        let checker = checker(FakeSource(snapshot(latest: "1.2.0")), resetState: true)
        await checker.check()
        XCTAssertTrue(checker.showsUpdateBanner)
    }

    func testNoBannerWhenUpToDateOrRequired() async {
        let upToDate = checker(FakeSource(snapshot(latest: "1.1.0", minimum: "1.0.0")))
        await upToDate.check()
        XCTAssertFalse(upToDate.showsUpdateBanner)

        let required = checker(FakeSource(snapshot(latest: "2.0.0", minimum: "2.0.0")))
        await required.check()
        XCTAssertFalse(required.showsUpdateBanner)
        required.dismissBanner() // no-op
        XCTAssertNil(defaults.string(forKey: VersionChecker.dismissedVersionKey))
    }

    func testUITestPolicySources() async throws {
        let required = try XCTUnwrap(LaunchArguments.testPolicySource(installed: "0.1.0", arguments: ["--uitest-version-policy", "required"]))
        let status = VersionEvaluator.evaluate(installed: "0.1.0", policy: await required.currentPolicy()?.policy)
        XCTAssertTrue(status.isRequired)
        XCTAssertNil(LaunchArguments.testPolicySource(installed: "0.1.0", arguments: []))
        XCTAssertNil(LaunchArguments.testPolicySource(installed: "0.1.0", arguments: ["--uitest-version-policy", "bogus"]))
    }
}
