import Foundation

/// Launch arguments used by UI tests (ios/SETUP.md, "UI tests").
/// Stores check `resetState` and skip loading persisted state for that launch,
/// instead of clearing `UserDefaults` and reading it straight back (which races).
enum LaunchArguments {
    static let resetStateFlag = "--uitest-reset-state"
    /// `--uitest-version-policy required|available|current`: a fixed version policy instead of the remote one (Debug only).
    static let versionPolicyFlag = "--uitest-version-policy"

    /// `--uitest-favorite-club 537:CHA`: start with this favourite instead of onboarding (Debug only).
    static let favoriteClubFlag = "--uitest-favorite-club"
    /// `--uitest-open bnxt://club/537`: open a deep link on launch (Debug only; playbook 03).
    static let openFlag = "--uitest-open"

    static func presetFavoriteClub(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> FavoriteClubStore.Saved? {
        #if DEBUG
        guard let value = value(of: favoriteClubFlag, in: arguments) else { return nil }
        let parts = value.split(separator: ":")
        guard parts.count == 2, let id = Int(parts[0]) else { return nil }
        return FavoriteClubStore.Saved(teamId: id, shortName: String(parts[1]))
        #else
        return nil
        #endif
    }

    static func openURL(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> URL? {
        #if DEBUG
        return value(of: openFlag, in: arguments).flatMap(URL.init(string:))
        #else
        return nil
        #endif
    }

    /// `--uitest-bundled-config`: use only the config bundled in the build (Debug only).
    static let bundledConfigFlag = "--uitest-bundled-config"

    static func bundledConfigOnly(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        return arguments.contains(bundledConfigFlag)
        #else
        return false
        #endif
    }

    /// `--uitest-offline`: every request fails as if there were no connection (Debug only; §4 Offline).
    static let offlineFlag = "--uitest-offline"
    /// `--uitest-clear-cache`: start with an empty response cache, as on a first launch (Debug only).
    static let clearCacheFlag = "--uitest-clear-cache"

    static func offline(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        return arguments.contains(offlineFlag)
        #else
        return false
        #endif
    }

    static func clearCache(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
        return arguments.contains(clearCacheFlag)
        #else
        return false
        #endif
    }

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
