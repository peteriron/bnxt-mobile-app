import Foundation

/// Settings the app reads at runtime without an app update (REQUIREMENTS §7.24): `config/v1/config.json`
/// in the repo, served from GitHub and bundled into every build as the offline fallback.
/// Decoded leniently: an unknown or malformed section falls back to its default instead of failing the whole file.
struct RemoteConfig: Sendable, Equatable, Decodable {
    /// The config schema this build understands. A file with a newer schema is still read for its version
    /// policy (so it can force an update), but its other sections are ignored.
    static let supportedSchema = 1
    /// The data contract this build speaks; `versionPolicy.minimumDataSchema` above it forces an update (§3.9).
    static let dataSchema = 1

    var schemaVersion: Int
    var season: Season?
    var versionPolicy: VersionPolicy?
    var minimumDataSchema: Int
    var features: Features
    var zones: [StandingsZone]
    var relegation: Bool
    /// The playoff format, for the projected brackets (§3.5). Nil hides the Playoffs view.
    var playoffs: PlayoffSettings?
    /// "How the season works" paragraphs per language (§3.5).
    var seasonExplainer: [String: [String]]
    var teams: [Int: TeamSettings]
    /// Replacement for the build's API key if the website rotates its key (§7.15). Absent in normal operation;
    /// adding it publishes the key in the public repo, so it's an emergency measure only.
    var apiKeyOverride: String?

    var isCompatible: Bool { schemaVersion <= Self.supportedSchema }

    typealias Features = RemoteFeatures

    struct TeamSettings: Sendable, Equatable, Decodable {
        var displayName: String?
        var city: String?
        /// Lets onboarding group clubs by country before (or without) the API.
        var country: Country?
        /// Dark logos that need a light plate on the dark UI (§7.26).
        var logoPlate: Bool?
        /// The club's brand colour, "#RRGGBB", curated from its logo (§7.25). Many are dark: graphics must
        /// lift them to 3:1 against the background before use.
        var color: String?

        /// `color` parsed; nil when missing or malformed.
        var rgb: RGB? { color.flatMap(RGB.init(hexString:)) }
    }

    /// A standings zone (§7.5): league position, or position among the clubs of one country.
    struct StandingsZone: Sendable, Hashable, Decodable {
        var id: String
        var label: String
        var color: String
        var country: Country?
        var leaguePositionAtMost: Int?
        var nationalPositionAtMost: Int?
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, season, versionPolicy, features, zones, relegation, playoffs, seasonExplainer, teams, apiKeyOverride
    }

    private enum PolicyKeys: String, CodingKey { case ios, minimumDataSchema }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = container.integer(forKey: .schemaVersion) ?? 1
        let policy = try? container.nestedContainer(keyedBy: PolicyKeys.self, forKey: .versionPolicy)
        versionPolicy = policy?.lenient(VersionPolicy.self, forKey: .ios)
        minimumDataSchema = policy?.integer(forKey: .minimumDataSchema) ?? 1
        apiKeyOverride = container.text(forKey: .apiKeyOverride)

        let compatible = schemaVersion <= Self.supportedSchema
        season = compatible ? container.lenient(Season.self, forKey: .season) : nil
        features = (compatible ? container.lenient(Features.self, forKey: .features) : nil) ?? Features()
        zones = compatible ? container.lossyArray(StandingsZone.self, forKey: .zones) : []
        relegation = (compatible ? container.lenient(Bool.self, forKey: .relegation) : nil) ?? false
        playoffs = compatible ? container.lenient(PlayoffSettings.self, forKey: .playoffs) : nil
        seasonExplainer = (compatible ? container.lenient([String: [String]].self, forKey: .seasonExplainer) : nil) ?? [:]
        let teams = (compatible ? container.lenient([String: TeamSettings].self, forKey: .teams) : nil) ?? [:]
        self.teams = Dictionary(uniqueKeysWithValues: teams.compactMap { key, value in Int(key).map { ($0, value) } })
    }

    /// The explainer in `language`, falling back to English.
    func seasonExplainer(for language: String) -> [String] {
        seasonExplainer[language] ?? seasonExplainer["en"] ?? []
    }

    /// The copy bundled into this build (the repo's config/v1/config.json at build time).
    static func bundled(in bundle: Bundle = .main) -> RemoteConfig? {
        guard let url = bundle.url(forResource: "config", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(RemoteConfig.self, from: data)
    }
}

/// Feature switches in the remote config.
struct RemoteFeatures: Sendable, Equatable, Decodable {
    /// Live play-by-play from FIBA LiveStats (§7.4); off switches the app to BNXT scores only.
    var liveStats = true

    private enum CodingKeys: String, CodingKey { case liveStats }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        liveStats = container.lenient(Bool.self, forKey: .liveStats) ?? true
    }
}

/// The playoff format per country (§3.5): how many clubs qualify follows from the rounds (a final is 2 clubs,
/// each earlier round doubles it), so the config only lists the rounds.
struct PlayoffSettings: Sendable, Equatable, Decodable {
    typealias Bracket = PlayoffBracketFormat
    typealias Round = PlayoffRound

    /// The first playoff day ("2027-05-14"), in league time.
    var startDate: String?
    var brackets: [Bracket]

    private enum CodingKeys: String, CodingKey { case startDate, brackets }

    init(startDate: String? = nil, brackets: [Bracket]) {
        self.startDate = startDate
        self.brackets = brackets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        startDate = container.text(forKey: .startDate)
        brackets = container.lossyArray(Bracket.self, forKey: .brackets)
    }
}

/// One country's playoff bracket in the config.
struct PlayoffBracketFormat: Sendable, Equatable, Decodable {
    var country: Country
    var label: String
    var rounds: [PlayoffRound]

    /// Clubs in the first round: 2 for a final alone, 4 with semi-finals, 8 with quarter-finals.
    var seeds: Int { rounds.isEmpty ? 0 : 1 << rounds.count }

    private enum CodingKeys: String, CodingKey { case country, label, rounds }

    init(country: Country, label: String, rounds: [PlayoffRound]) {
        self.country = country
        self.label = label
        self.rounds = rounds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        country = try container.decode(Country.self, forKey: .country)
        label = container.text(forKey: .label) ?? ""
        rounds = container.lossyArray(PlayoffRound.self, forKey: .rounds)
    }
}

struct PlayoffRound: Sendable, Equatable, Decodable {
    var label: String
    var bestOf: Int
}
