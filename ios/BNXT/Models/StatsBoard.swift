import Foundation

/// The team categories on the Stats tab (§3.6). Chip order follows the prototype.
enum TeamStatCategory: String, CaseIterable, Identifiable, Sendable {
    case points, pointsAllowed, rebounds, assists, fieldGoalPercentage, threePointPercentage, steals, turnovers

    var id: Self { self }

    /// Points allowed and turnovers rank lowest first (§3.6).
    var lowerIsBetter: Bool { self == .pointsAllowed || self == .turnovers }

    var isPercentage: Bool { self == .fieldGoalPercentage || self == .threePointPercentage }
}

/// One club's season, summed from its finished games' own totals (`Game.teamTotals`).
struct TeamSeasonStats: Hashable, Sendable {
    let teamId: Int
    let games: Int
    let totals: StatLine
    let pointsScored: Double
    let pointsAllowed: Double

    /// nil when the club has no usable finished game in `phaseIds` (an empty list or a missing phase is ignored).
    static func from(_ games: [Game], teamId: Int, phaseIds: [Int]) -> TeamSeasonStats? {
        var count = 0, totals = StatLine(), scored = 0.0, allowed = 0.0
        for game in games where game.status == .finished {
            if let phase = game.phaseId, !phaseIds.isEmpty, !phaseIds.contains(phase) { continue }
            guard let line = game.teamTotals else { continue }
            let isHome = game.home.team.id == teamId
            guard isHome || game.away.team.id == teamId else { continue }
            let own = isHome ? game.home : game.away, other = isHome ? game.away : game.home
            guard let ownScore = own.score, let otherScore = other.score else { continue }
            count += 1
            totals = totals.adding(line)
            scored += Double(ownScore)
            allowed += Double(otherScore)
        }
        guard count > 0 else { return nil }
        return TeamSeasonStats(teamId: teamId, games: count, totals: totals, pointsScored: scored, pointsAllowed: allowed)
    }

    /// Per game, or a percentage over the season's attempts; nil for a percentage with no attempts.
    func value(_ category: TeamStatCategory) -> Double? {
        let perGame = 1 / Double(games)
        switch category {
        case .points: return pointsScored * perGame
        case .pointsAllowed: return pointsAllowed * perGame
        case .rebounds: return totals.rebounds * perGame
        case .assists: return totals.assists * perGame
        case .steals: return totals.steals * perGame
        case .turnovers: return totals.turnovers * perGame
        case .fieldGoalPercentage: return totals.fieldGoalPercentage
        case .threePointPercentage: return totals.threePointPercentage
        }
    }
}

/// Pure derivations for the Stats tab (§3.6).
enum StatsBoard {
    /// How many player ranks the list shows (the hero is #1).
    static let playerLimit = 20

    struct PlayerRow: Identifiable, Hashable, Sendable {
        var id: Int { entry.rosterId }
        let rank: Int
        let entry: LeaderEntry
        /// Bar length, 0...1, relative to #1.
        let fraction: Double
    }

    /// The league's top 20 in a category, as the league ranks them (its minimum-attempt rules apply).
    static func playerRows(_ leaders: PlayerLeaders?, category: LeaderCategory) -> [PlayerRow] {
        let entries = Array((leaders?[category] ?? []).prefix(playerLimit))
        let top = entries.map(\.value).max() ?? 0
        return entries.enumerated().map { index, entry in
            PlayerRow(rank: index + 1, entry: entry, fraction: top > 0 ? max(0, entry.value / top) : 0)
        }
    }

    struct TeamRow: Identifiable, Hashable, Sendable {
        var id: Int { teamId }
        let rank: Int
        let teamId: Int
        let value: Double
        /// Bar length, 0.2...1: the lowest value gets a stub, the highest a full bar (prototype).
        let fraction: Double
    }

    /// Clubs ranked best first; lower-is-better categories ascend. Clubs without a value are left out.
    static func teamRows(_ stats: [TeamSeasonStats], category: TeamStatCategory) -> [TeamRow] {
        let values = stats.compactMap { stat in stat.value(category).map { (stat.teamId, $0) } }
        let sorted = values.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return category.lowerIsBetter ? lhs.1 < rhs.1 : lhs.1 > rhs.1 }
            return lhs.0 < rhs.0 // stable for equal values
        }
        let low = values.map(\.1).min() ?? 0, high = values.map(\.1).max() ?? 0
        return sorted.enumerated().map { index, item in
            let fraction = high > low ? 0.2 + 0.8 * (item.1 - low) / (high - low) : 1
            return TeamRow(rank: index + 1, teamId: item.0, value: item.1, fraction: fraction)
        }
    }
}
