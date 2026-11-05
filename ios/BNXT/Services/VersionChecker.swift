import Foundation
import Observation

/// The current version policy, wherever it came from.
struct PolicySnapshot: Sendable, Equatable {
    var policy: VersionPolicy?
    var minimumDataSchema = 1
}

protocol VersionPolicySource: Sendable {
    /// nil when no policy is available at all.
    func currentPolicy() async -> PolicySnapshot?
}

/// Keeps users on a build that works (REQUIREMENTS §3.9, §7.18).
///
/// Checks on launch and when the app returns to the foreground, at most once per `minimumInterval` unless forced.
/// A failed check keeps the previous status: a network failure never blocks the app.
@MainActor @Observable
final class VersionChecker {
    private(set) var status: UpdateStatus = .unknown
    /// The policy behind `status` (for the store link and the message).
    private(set) var policy: VersionPolicy?
    private(set) var dismissedVersion: String?

    let installedVersion: String
    let minimumInterval: TimeInterval

    @ObservationIgnored private let source: VersionPolicySource
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var lastCheck: Date?

    static let dismissedVersionKey = "versionChecker.dismissedVersion"

    init(source: VersionPolicySource,
         installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
         defaults: UserDefaults = .standard,
         resetState: Bool = LaunchArguments.resetState(),
         minimumInterval: TimeInterval = 6 * 3600,
         now: @escaping () -> Date = Date.init) {
        self.source = source
        self.installedVersion = installedVersion
        self.defaults = defaults
        self.minimumInterval = minimumInterval
        self.now = now
        // UI tests start clean by skipping the load (LaunchArguments), not by clearing and re-reading defaults.
        dismissedVersion = resetState ? nil : defaults.string(forKey: Self.dismissedVersionKey)
    }

    /// Show the Home banner: an update is available and this latest version hasn't been dismissed.
    var showsUpdateBanner: Bool {
        guard case let .updateAvailable(latest) = status else { return false }
        return latest.description != dismissedVersion
    }

    func check(force: Bool = false) async {
        if !force, let lastCheck, now().timeIntervalSince(lastCheck) < minimumInterval { return }
        lastCheck = now()
        guard let snapshot = await source.currentPolicy() else { return } // keep the previous status
        policy = snapshot.policy
        status = VersionEvaluator.evaluate(installed: installedVersion, policy: snapshot.policy,
                                           minimumDataSchema: snapshot.minimumDataSchema)
    }

    /// Hides the banner for this latest version; a newer one shows it again.
    func dismissBanner() {
        guard case let .updateAvailable(latest) = status else { return }
        dismissedVersion = latest.description
        defaults.set(latest.description, forKey: Self.dismissedVersionKey)
    }
}

/// A fixed policy: UI tests and previews (`--uitest-version-policy`).
struct StaticPolicySource: VersionPolicySource {
    var snapshot: PolicySnapshot?

    func currentPolicy() async -> PolicySnapshot? { snapshot }
}
