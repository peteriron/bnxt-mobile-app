import Foundation

/// Where data comes from and how to authenticate.
///
/// For now the app talks straight to the BNXT API with the website's client key (REQUIREMENTS.md §7.15)
/// and reads live play-by-play from the public FIBA LiveStats feed (§7.4). The key arrives at build time:
/// `Config/Secrets.xcconfig` → `BNXT_API_KEY` → Info.plist `BNXTAPIKey`. It is never committed.
struct APIConfiguration: Equatable, Sendable {
    static let infoPlistKey = "BNXTAPIKey"

    static let defaultBaseURL = URL(string: "https://bnxt.sportpress.info/api/v1/")!
    static let defaultLiveStatsURL = URL(string: "https://fibalivestats.dcd.shared.geniussports.com/data/")!

    let baseURL: URL
    let liveStatsURL: URL
    let apiKey: String

    init(apiKey: String, baseURL: URL = Self.defaultBaseURL, liveStatsURL: URL = Self.defaultLiveStatsURL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.liveStatsURL = liveStatsURL
    }

    /// Reads the key from an Info.plist dictionary. Returns nil when it's missing, empty, or an
    /// unexpanded build variable (a build made without Secrets.xcconfig).
    init?(infoDictionary: [String: Any]?) {
        guard let raw = infoDictionary?[Self.infoPlistKey] as? String else { return nil }
        let key = raw.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !key.hasPrefix("$("), key != "paste-the-key-here" else { return nil }
        self.init(apiKey: key)
    }

    /// The configuration of this build, or nil if it was built without a key.
    static let main = APIConfiguration(infoDictionary: Bundle.main.infoDictionary)

    /// The headers the website sends; the API returns 401 without `X-Authorization`.
    var headers: [String: String] {
        ["X-Authorization": apiKey, "Accept": "application/json"]
    }

    /// URL of the FIBA LiveStats JSON for a game's `genius_id`.
    func liveStatsURL(geniusId: Int) -> URL {
        liveStatsURL.appending(path: "\(geniusId)/data.json")
    }
}

extension APIConfiguration: CustomStringConvertible {
    /// Never prints the key (CLAUDE.md, "Data and secrets").
    var description: String { "APIConfiguration(baseURL: \(baseURL), apiKey: <redacted>)" }
}
