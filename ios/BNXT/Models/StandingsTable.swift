import Foundation

/// Which table the Standings screen shows (§3.5).
enum StandingsScope: Hashable, Sendable {
    case league
    case country(Country)
}

/// The standings as the UI shows them: rank, zone and cut line per scope, derived from the API rows and the
/// config's zones (§7.5). Pure, so the rules are unit-tested; the prototype's `rankIn` / `zone` are the reference.
struct StandingsTable: Sendable {
    struct Row: Identifiable, Hashable, Sendable {
        var id: Int { standing.id }
        let standing: Standing
        /// League position, or the rank among the clubs of the scope's country.
        let rank: Int
        let zone: RemoteConfig.StandingsZone?
    }

    let standings: [Standing]
    let zones: [RemoteConfig.StandingsZone]
    /// Country per team id, for rows whose API team has none (config fills it in).
    let countries: [Int: Country]

    init(standings: [Standing], zones: [RemoteConfig.StandingsZone], countries: [Int: Country] = [:]) {
        self.standings = standings.sorted { $0.position < $1.position }
        self.zones = zones
        self.countries = countries
    }

    func country(of standing: Standing) -> Country? {
        standing.team.country ?? countries[standing.team.id]
    }

    /// League order, or the clubs of one country re-ranked 1…n.
    func rows(for scope: StandingsScope) -> [Row] {
        switch scope {
        case .league:
            return standings.map { Row(standing: $0, rank: $0.position, zone: zone(of: $0)) }
        case let .country(country):
            return national(country).enumerated().map { index, standing in
                let rank = index + 1
                let zone = zones.first { $0.country == country && ($0.nationalPositionAtMost.map { rank <= $0 } ?? false) }
                return Row(standing: standing, rank: rank, zone: zone)
            }
        }
    }

    /// The zone shown in the league table: the first config zone the club qualifies for.
    func zone(of standing: Standing) -> RemoteConfig.StandingsZone? {
        zones.first { zone in
            if let most = zone.leaguePositionAtMost, standing.position <= most { return true }
            if let most = zone.nationalPositionAtMost, let country = zone.country, country == self.country(of: standing),
               let rank = nationalRank(of: standing.team.id), rank <= most { return true }
            return false
        }
    }

    /// 1-based rank among the clubs of the same country.
    func nationalRank(of teamId: Int) -> Int? {
        guard let standing = standings.first(where: { $0.team.id == teamId }), let country = country(of: standing) else { return nil }
        return national(country).firstIndex { $0.team.id == teamId }.map { $0 + 1 }
    }

    /// The national rank after which the dashed cut line is drawn, or nil (league table, or no zone for the country).
    func cutLine(for scope: StandingsScope) -> Int? {
        guard case let .country(country) = scope else { return nil }
        return zones.first { $0.country == country }?.nationalPositionAtMost
    }

    /// Zones that apply to a scope, for its legend.
    func legendZones(for scope: StandingsScope) -> [RemoteConfig.StandingsZone] {
        switch scope {
        case .league: zones
        case let .country(country): zones.filter { $0.country == country }
        }
    }

    /// "after N of 30 games": the most games any club has played.
    var gamesPlayed: Int { standings.map(\.played).max() ?? 0 }

    private func national(_ country: Country) -> [Standing] {
        standings.filter { self.country(of: $0) == country }
    }
}

/// A playoff bracket "if the season ended today" (§3.5): the first round is seeded from the national table,
/// later rounds are to be decided.
struct ProjectedBracket: Sendable, Equatable {
    struct Seed: Sendable, Equatable {
        let seed: Int
        let standing: Standing?
    }

    struct Matchup: Sendable, Equatable {
        let higher: Seed
        let lower: Seed
    }

    struct Round: Sendable, Equatable {
        let label: String
        let bestOf: Int
        /// Only the first round has known clubs; later rounds have `matchupCount` empty slots.
        let matchups: [Matchup]
        let matchupCount: Int
    }

    let country: Country
    let label: String
    let rounds: [Round]

    init(bracket: PlayoffSettings.Bracket, table: StandingsTable) {
        country = bracket.country
        label = bracket.label
        let ranked = table.rows(for: .country(bracket.country)).map(\.standing)
        let seeds = bracket.seeds
        rounds = bracket.rounds.enumerated().map { index, round in
            let count = max(seeds >> (index + 1), 1)
            let matchups: [Matchup] = index == 0
                ? Self.firstRoundPairs(seeds: seeds).map { higher, lower in
                    Matchup(higher: Seed(seed: higher, standing: ranked[safe: higher - 1]),
                            lower: Seed(seed: lower, standing: ranked[safe: lower - 1]))
                }
                : []
            return Round(label: round.label, bestOf: round.bestOf, matchups: matchups, matchupCount: count)
        }
    }

    /// Standard bracket order, top to bottom, so seeds 1 and 2 can only meet in the final:
    /// 8 → 1v8, 4v5, 2v7, 3v6; 4 → 1v4, 2v3; 2 → 1v2.
    static func firstRoundPairs(seeds: Int) -> [(Int, Int)] {
        guard seeds >= 2 else { return [] }
        var order = [1]
        while order.count < seeds {
            let size = order.count * 2
            order = order.flatMap { [$0, size + 1 - $0] }
        }
        // Order is [1, 8, 4, 5, 2, 7, 3, 6]; pair neighbours.
        return stride(from: 0, to: order.count, by: 2).map { (order[$0], order[$0 + 1]) }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
