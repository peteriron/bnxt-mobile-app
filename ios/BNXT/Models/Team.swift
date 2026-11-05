import Foundation

/// A club in one competition (a "competition team" upstream; its id changes every season, REQUIREMENTS §7.14).
struct Team: Identifiable, Hashable, Sendable, Decodable {
    let id: Int
    /// Official name, sponsors included ("Val-Dieu Spirou Basket"). Display names come from config later.
    let name: String
    /// Three-letter code ("CHA").
    let shortName: String
    /// Missing in some responses (leaders, game sides).
    let country: Country?
    let ticketURL: URL?
    let logo: RemoteImage?
    /// Only `competition-team/find` sends these; elsewhere the field is an empty list or absent.
    let statistics: TeamStatistics?

    private enum CodingKeys: String, CodingKey {
        case id, name, club
        case shortName = "short_name"
        case ticketURL = "ticket_url"
        case logo = "team_logo"
        case statistics
    }

    private struct Club: Decodable { let id: Int }

    init(id: Int, name: String, shortName: String, country: Country? = nil, ticketURL: URL? = nil,
         logo: RemoteImage? = nil, statistics: TeamStatistics? = nil) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.country = country
        self.ticketURL = ticketURL
        self.logo = logo
        self.statistics = statistics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.requiredInteger(forKey: .id)
        name = try container.requiredText(forKey: .name)
        shortName = container.text(forKey: .shortName) ?? String(name.prefix(3)).uppercased()
        country = container.lenient(Club.self, forKey: .club).flatMap { Country(upstreamClubId: $0.id) }
        ticketURL = container.url(forKey: .ticketURL)
        logo = container.lenient(RemoteImage.self, forKey: .logo)
        statistics = container.lenient(TeamStatistics.self, forKey: .statistics)
    }
}

/// Season averages the API computes per team (`competition-team/find`).
struct TeamStatistics: Hashable, Sendable, Decodable {
    let pointsFor: Double
    let pointsAgainst: Double
    let fieldGoalPercentage: Double

    private enum CodingKeys: String, CodingKey {
        case pointsFor = "average_score_for"
        case pointsAgainst = "average_score_against"
        case fieldGoalPercentage = "field_goal_percent"
    }

    init(pointsFor: Double, pointsAgainst: Double, fieldGoalPercentage: Double) {
        self.pointsFor = pointsFor
        self.pointsAgainst = pointsAgainst
        self.fieldGoalPercentage = fieldGoalPercentage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let pointsFor = container.number(forKey: .pointsFor), let pointsAgainst = container.number(forKey: .pointsAgainst) else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "No team averages"))
        }
        self.init(pointsFor: pointsFor, pointsAgainst: pointsAgainst, fieldGoalPercentage: container.number(forKey: .fieldGoalPercentage) ?? 0)
    }
}

/// A logo or photo: the full image plus the API's thumbnails (transparent PNGs).
struct RemoteImage: Hashable, Sendable, Decodable {
    let url: URL
    let small: URL?
    let medium: URL?

    private enum CodingKeys: String, CodingKey {
        case url = "public_url"
        case thumbnails
    }

    private enum ThumbnailKeys: String, CodingKey { case small, medium }

    init(url: URL, small: URL? = nil, medium: URL? = nil) {
        self.url = url
        self.small = small
        self.medium = medium
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let url = container.url(forKey: .url) else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "No image URL"))
        }
        let thumbs = try? container.nestedContainer(keyedBy: ThumbnailKeys.self, forKey: .thumbnails)
        self.init(url: url, small: thumbs?.url(forKey: .small), medium: thumbs?.url(forKey: .medium))
    }
}
