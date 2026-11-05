import Foundation

/// A `MAJOR.MINOR.PATCH` version. Missing parts are 0 ("1.2" == "1.2.0"); a pre-release suffix is ignored
/// ("1.4.0-beta" == "1.4.0"); comparison is numeric, so 1.10.0 > 1.9.9.
struct SemanticVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    let major: Int, minor: Int, patch: Int

    init?(_ string: String) {
        // Keep empty parts: "-1.0" must fail, not lose its leading "-" and parse as 1.0.0.
        let core = string.trimmingCharacters(in: .whitespaces)
            .split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count) else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(\.isASCII), let value = Int(part), value >= 0 else { return nil }
            numbers.append(value)
        }
        numbers += Array(repeating: 0, count: 3 - numbers.count)
        (major, minor, patch) = (numbers[0], numbers[1], numbers[2])
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    var description: String { "\(major).\(minor).\(patch)" }
}

/// `versionPolicy.ios` from the remote config (REQUIREMENTS §3.9).
struct VersionPolicy: Sendable, Equatable, Decodable {
    var latestVersion: String?
    var minimumVersion: String?
    var blockedVersions: [String] = []
    /// The App Store page. Optional until the app has one; the update screens then name the App Store instead.
    var storeURL: URL?
    /// Localised explanation for the blocking screen, keyed by language code.
    var message: [String: String] = [:]

    init(latestVersion: String? = nil, minimumVersion: String? = nil, blockedVersions: [String] = [],
         storeURL: URL? = nil, message: [String: String] = [:]) {
        self.latestVersion = latestVersion
        self.minimumVersion = minimumVersion
        self.blockedVersions = blockedVersions
        self.storeURL = storeURL
        self.message = message
    }

    private enum CodingKeys: String, CodingKey { case latestVersion, minimumVersion, blockedVersions, storeURL, message }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        latestVersion = container.text(forKey: .latestVersion)
        minimumVersion = container.text(forKey: .minimumVersion)
        blockedVersions = container.lossyArray(String.self, forKey: .blockedVersions)
        storeURL = container.url(forKey: .storeURL)
        message = container.lenient([String: String].self, forKey: .message) ?? [:]
    }

    /// Why this policy can't be trusted, or nil if it's sound. An unsound policy is ignored by the app
    /// (treated as no policy), so a typo in the config can never lock users out.
    var problem: String? {
        if let latestVersion, SemanticVersion(latestVersion) == nil { return "latestVersion \"\(latestVersion)\" isn't x.y.z" }
        if let minimumVersion, SemanticVersion(minimumVersion) == nil { return "minimumVersion \"\(minimumVersion)\" isn't x.y.z" }
        if let bad = blockedVersions.first(where: { SemanticVersion($0) == nil }) { return "blockedVersions has \"\(bad)\"" }
        if let latest = latestVersion.flatMap(SemanticVersion.init), let minimum = minimumVersion.flatMap(SemanticVersion.init),
           minimum > latest {
            return "minimumVersion \(minimum) is above latestVersion \(latest)"
        }
        if let storeURL, storeURL.scheme != "https" { return "storeURL must be https" }
        return nil
    }

    func message(for language: String) -> String? {
        message[language] ?? message["en"]
    }
}

enum UpdateStatus: Equatable, Sendable {
    /// No usable policy (none fetched yet, or unsound). Behaves like `.upToDate`.
    case unknown
    case upToDate
    case updateAvailable(latest: SemanticVersion)
    case updateRequired(reason: Reason)

    enum Reason: Equatable, Sendable {
        case belowMinimum(SemanticVersion)
        case blocked
        case dataSchemaTooOld
    }

    var isRequired: Bool {
        if case .updateRequired = self { return true }
        return false
    }
}

/// The version-checker rules (REQUIREMENTS §3.9), as a pure function.
enum VersionEvaluator {
    static func evaluate(installed: String, policy: VersionPolicy?, minimumDataSchema: Int = 1,
                         dataSchema: Int = RemoteConfig.dataSchema) -> UpdateStatus {
        // 1. No policy, an unsound one, or an unparsable installed version: unknown.
        guard let policy, policy.problem == nil, let current = SemanticVersion(installed) else { return .unknown }
        // 2. Explicitly blocked.
        if policy.blockedVersions.compactMap(SemanticVersion.init).contains(current) {
            return .updateRequired(reason: .blocked)
        }
        // 3. Below the minimum.
        if let minimum = policy.minimumVersion.flatMap(SemanticVersion.init), current < minimum {
            return .updateRequired(reason: .belowMinimum(minimum))
        }
        // 4. The data contract moved on.
        if dataSchema < minimumDataSchema {
            return .updateRequired(reason: .dataSchemaTooOld)
        }
        // 5. A newer version exists.
        if let latest = policy.latestVersion.flatMap(SemanticVersion.init), current < latest {
            return .updateAvailable(latest: latest)
        }
        // 6.
        return .upToDate
    }
}
