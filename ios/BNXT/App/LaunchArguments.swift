import Foundation

/// Launch arguments used by UI tests (ios/SETUP.md, "UI tests").
/// Stores check `resetState` and skip loading persisted state for that launch,
/// instead of clearing `UserDefaults` and reading it straight back (which races).
enum LaunchArguments {
    static let resetStateFlag = "--uitest-reset-state"
    /// `--uitest-version-policy required|available|current`: a fixed version policy instead of the remote one (Debug only).
    static let versionPolicyFlag = "--uitest-version-policy"

    static func resetState(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(resetStateFlag)
    }

    /// The value after `flag`, if present.
    static func value(of flag: String, in arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    /// A fixed policy relative to `installed` for UI tests, or nil to use the remote config.
    static func testPolicySource(installed: String, arguments: [String] = ProcessInfo.processInfo.arguments) -> StaticPolicySource? {
        #if DEBUG
        guard let mode = value(of: versionPolicyFlag, in: arguments), let current = SemanticVersion(installed) else { return nil }
        let next = "\(current.major).\(current.minor).\(current.patch + 1)"
        let store = URL(string: "https://apps.apple.com/")
        switch mode {
        case "required":
            return StaticPolicySource(snapshot: PolicySnapshot(policy: VersionPolicy(latestVersion: next, minimumVersion: next, storeURL: store,
                                                                                     message: ["en": "This version needs an update."])))
        case "available":
            return StaticPolicySource(snapshot: PolicySnapshot(policy: VersionPolicy(latestVersion: next, minimumVersion: installed, storeURL: store)))
        case "current":
            return StaticPolicySource(snapshot: PolicySnapshot(policy: VersionPolicy(latestVersion: installed, minimumVersion: installed)))
        default:
            return nil
        }
        #else
        return nil
        #endif
    }
}
