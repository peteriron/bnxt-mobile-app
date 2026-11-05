import Foundation

/// The league's player rankings (`player/average-rankings/{cid}?phase_id=`), per category.
/// Unlike other endpoints this one has no `data` envelope: categories are top-level keys.
struct PlayerLeaders: Sendable, Decodable {
    let categories: [LeaderCategory: [LeaderEntry]]

    subscript(category: LeaderCategory) -> [LeaderEntry] { categories[category] ?? [] }

    /// 1-based rank of a roster entry in a category, or nil if unranked.
    func rank(of rosterId: Int, in category: LeaderCategory) -> Int? {
        self[category].firstIndex { $0.rosterId == rosterId }.map { $0 + 1 }
    }

    init(categories: [LeaderCategory: [LeaderEntry]]) {
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyKey.self)
        var categories: [LeaderCategory: [LeaderEntry]] = [:]
        for key in container.allKeys {
            guard let category = LeaderCategory(rawValue: key.stringValue) else { continue } // unknown categories are ignored
            categories[category] = container.lossyArray(LeaderEntry.self, forKey: key)
        }
        self.categories = categories
    }

    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }
}

enum LeaderCategory: String, CaseIterable, Sendable {
    case efficiency
    case points
    case rebounds = "total_rebound"
    case assists = "assist"
    case steals = "steal"
    case blocks = "block"
    case twoPointPercentage = "two_point_percent"
    case threePointPercentage = "three_point_percent"
    case freeThrowPercentage = "free_throw_percent"

    var isPercentage: Bool {
        switch self {
        case .twoPointPercentage, .threePointPercentage, .freeThrowPercentage: true
        default: false
        }
    }
}

struct LeaderEntry: Hashable, Sendable, Decodable {
    let player: Player
    /// Leader entries carry no country.
    let team: Team
    let rosterId: Int
    let value: Double

    private enum CodingKeys: String, CodingKey {
        case player, team, value
        case rosterId = "roster_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        player = try container.decode(Player.self, forKey: .player)
        team = try container.decode(Team.self, forKey: .team)
        rosterId = try container.requiredInteger(forKey: .rosterId)
        guard let value = container.number(forKey: .value) else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "No value")
        }
        self.value = value
    }
}
