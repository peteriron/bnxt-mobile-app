import Foundation

/// Pure derivations for the player page (§3.8): season averages from the game log, league-rank badges,
/// the points chart and game-log rows.
enum PlayerPage {
    /// Season totals and per-game averages over the games played.
    struct SeasonStats: Hashable, Sendable {
        let games: Int
        let totals: StatLine
        let perGame: StatLine
    }

    /// nil when the player hasn't played yet (the page then shows the bio only).
    static func season(_ lines: [PlayerGameLine]) -> SeasonStats? {
        guard !lines.isEmpty else { return nil }
        var totals = StatLine()
        for line in lines { totals = totals.adding(line.stats) }
        return SeasonStats(games: lines.count, totals: totals, perGame: totals.divided(by: Double(lines.count)))
    }

    /// Badges are shown for top-10 ranks only.
    static let badgeLimit = 10

    /// "#N in league" for a stat, when the player is in the league's top 10.
    static func leagueRank(_ leaders: PlayerLeaders?, rosterId: Int, category: LeaderCategory) -> Int? {
        guard let rank = leaders?.rank(of: rosterId, in: category), rank <= badgeLimit else { return nil }
        return rank
    }

    /// One game in the log, from the player's side.
    struct LogRow: Identifiable, Hashable, Sendable {
        var id: Int { line.game.id }
        let line: PlayerGameLine
        let opponent: Team
        let isHome: Bool
        /// nil for unfinished games and ties.
        let won: Bool?
        let teamScore: Int?
        let opponentScore: Int?
    }

    /// The game log, newest first.
    static func log(_ lines: [PlayerGameLine]) -> [LogRow] {
        lines.sorted { $0.game.tipOff > $1.game.tipOff }.map(row)
    }

    static func row(_ line: PlayerGameLine) -> LogRow {
        let game = line.game
        // The team id in a game-log line is the player's competition team; fall back to "home" if it matches neither.
        let isHome = game.away.team.id != line.teamId
        let own = isHome ? game.home : game.away, other = isHome ? game.away : game.home
        return LogRow(line: line, opponent: other.team, isHome: isHome,
                      won: game.winner.map { $0.id == own.team.id }, teamScore: own.score, opponentScore: other.score)
    }

    /// Points per game, oldest first, labelled with the opponent's code.
    static func pointsChart(_ lines: [PlayerGameLine]) -> (values: [Double], labels: [String]) {
        let rows = log(lines).reversed()
        return (rows.map(\.line.stats.points), rows.map(\.opponent.shortName))
    }

    /// The most recent jersey number in the log (rosters often have none).
    static func jersey(entry: RosterEntry?, lines: [PlayerGameLine]) -> String? {
        if let jersey = entry?.jersey, !jersey.isEmpty { return jersey }
        return log(lines).lazy.compactMap { $0.line.jersey?.isEmpty == false ? $0.line.jersey : nil }.first
    }
}

extension StatLine {
    func adding(_ other: StatLine) -> StatLine {
        combined(with: other, +)
    }

    func divided(by divisor: Double) -> StatLine {
        guard divisor > 0 else { return self }
        return combined(with: self) { value, _ in value / divisor }
    }

    private func combined(with other: StatLine, _ operation: (Double, Double) -> Double) -> StatLine {
        var result = StatLine()
        result.minutes = operation(minutes, other.minutes)
        result.points = operation(points, other.points)
        result.twoPointersMade = operation(twoPointersMade, other.twoPointersMade)
        result.twoPointersAttempted = operation(twoPointersAttempted, other.twoPointersAttempted)
        result.threePointersMade = operation(threePointersMade, other.threePointersMade)
        result.threePointersAttempted = operation(threePointersAttempted, other.threePointersAttempted)
        result.fieldGoalsMade = operation(fieldGoalsMade, other.fieldGoalsMade)
        result.fieldGoalsAttempted = operation(fieldGoalsAttempted, other.fieldGoalsAttempted)
        result.freeThrowsMade = operation(freeThrowsMade, other.freeThrowsMade)
        result.freeThrowsAttempted = operation(freeThrowsAttempted, other.freeThrowsAttempted)
        result.offensiveRebounds = operation(offensiveRebounds, other.offensiveRebounds)
        result.defensiveRebounds = operation(defensiveRebounds, other.defensiveRebounds)
        result.rebounds = operation(rebounds, other.rebounds)
        result.assists = operation(assists, other.assists)
        result.steals = operation(steals, other.steals)
        result.blocks = operation(blocks, other.blocks)
        result.turnovers = operation(turnovers, other.turnovers)
        result.fouls = operation(fouls, other.fouls)
        result.efficiency = operation(efficiency, other.efficiency)
        if let mine = plusMinus, let theirs = other.plusMinus { result.plusMinus = operation(mine, theirs) }
        return result
    }
}
