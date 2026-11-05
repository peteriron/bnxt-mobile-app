import Foundation

/// A club as the UI shows it: the API team merged with its remote-config entry (display name, city, colour, logo plate).
/// Works from either source alone, so onboarding can run before (or without) the API.
struct Club: Identifiable, Hashable, Sendable {
    let id: Int
    let shortName: String
    /// The short name fans use ("Spirou Basket"); falls back to the official name.
    let displayName: String
    /// Sponsors included ("Val-Dieu Spirou Basket").
    let officialName: String
    let city: String?
    let country: Country?
    let logoURL: URL?
    let ticketURL: URL?
    /// The true brand colour (§7.25). May be too dark for graphics; use `graphicColor`.
    let brandColor: RGB?
    /// Dark logos get a light plate (§7.26).
    let needsLogoPlate: Bool

    /// The brand colour lifted to 3:1 on ink, for gradients, bars and rings (§5.1). Never for text.
    var graphicColor: RGB { (brandColor ?? .violet).lifted(toContrast: 3, against: .ink) }

    init(id: Int, shortName: String, displayName: String, officialName: String, city: String? = nil, country: Country? = nil,
         logoURL: URL? = nil, ticketURL: URL? = nil, brandColor: RGB? = nil, needsLogoPlate: Bool = false) {
        self.id = id
        self.shortName = shortName
        self.displayName = displayName
        self.officialName = officialName
        self.city = city
        self.country = country
        self.logoURL = logoURL
        self.ticketURL = ticketURL
        self.brandColor = brandColor
        self.needsLogoPlate = needsLogoPlate
    }

    init(team: Team, settings: RemoteConfig.TeamSettings?) {
        self.init(id: team.id,
                  shortName: team.shortName,
                  displayName: settings?.displayName ?? team.name,
                  officialName: team.name,
                  city: settings?.city,
                  country: team.country ?? settings?.country,
                  logoURL: team.logo?.medium ?? team.logo?.url,
                  ticketURL: team.ticketURL,
                  brandColor: settings?.rgb,
                  needsLogoPlate: settings?.logoPlate ?? false)
    }

    /// Config-only club (no API data yet): no logo, no ticket link; the short name is derived.
    init?(id: Int, settings: RemoteConfig.TeamSettings) {
        guard let name = settings.displayName else { return nil }
        let letters = name.filter(\.isLetter)
        self.init(id: id, shortName: String(letters.prefix(3)).uppercased(), displayName: name, officialName: name,
                  city: settings.city, country: settings.country, brandColor: settings.rgb, needsLogoPlate: settings.logoPlate ?? false)
    }

    /// All clubs: API teams merged with config; config-only clubs fill in when the API had nothing.
    /// Sorted by display name.
    static func merge(teams: [Team], config: RemoteConfig?) -> [Club] {
        let settings = config?.teams ?? [:]
        var clubs = teams.map { Club(team: $0, settings: settings[$0.id]) }
        if teams.isEmpty {
            clubs = settings.compactMap { Club(id: $0.key, settings: $0.value) }
        }
        return clubs.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
