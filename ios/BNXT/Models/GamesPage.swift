import Foundation

/// The Games tab's rules (§3.3): filter, live pinning, grouping by day and order.
enum GamesList {
    enum Mode: Hashable, Sendable { case upcoming, results }

    struct Day: Identifiable, Hashable, Sendable {
        /// Start of the day in league time.
        let date: Date
        let games: [Game]
        var id: Date { date }
    }

    struct Sections: Hashable, Sendable {
        /// Only in Upcoming: games in progress, pinned above the days.
        let live: [Game]
        let days: [Day]
    }

    static func sections(_ games: [Game], mode: Mode, clubId: Int?) -> Sections {
        let unique = Dictionary(games.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        let filtered = unique.filter { game in clubId.map(game.involves) ?? true }
        switch mode {
        case .upcoming:
            let live = filtered.filter(\.isLive).sorted { $0.tipOff < $1.tipOff }
            let scheduled = filtered.filter { $0.status == .scheduled }.sorted { ($0.tipOff, $0.id) < ($1.tipOff, $1.id) }
            return Sections(live: live, days: group(scheduled, newestFirst: false))
        case .results:
            let finished = filtered.filter { $0.status == .finished }.sorted { ($0.tipOff, $0.id) > ($1.tipOff, $1.id) }
            return Sections(live: [], days: group(finished, newestFirst: true))
        }
    }

    private static func group(_ games: [Game], newestFirst: Bool) -> [Day] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GameTime.leagueTimeZone
        let byDay = Dictionary(grouping: games) { calendar.startOfDay(for: $0.tipOff) }
        // Grouping keeps the order the caller sorted in within a day.
        return byDay.sorted { newestFirst ? $0.key > $1.key : $0.key < $1.key }.map { Day(date: $0.key, games: $0.value) }
    }
}

extension Game {
    var isLive: Bool {
        if case .inProgress = status { return true }
        return false
    }
}

/// Which side a team-comparison row favours.
enum ComparisonWinner: Hashable, Sendable { case home, away, neither }

/// Game detail rules (§3.4).
enum GameDetail {
    enum Tab: String, Hashable, CaseIterable, Sendable {
        case playByPlay, summary, boxScore, preview, info
    }

    /// Live: Play-by-play · Box score · Summary · Info. Final: Summary · Box score · Info.
    /// Upcoming: Preview · Info.
    static func tabs(for game: Game) -> [Tab] {
        switch game.status {
        case .finished: [.summary, .boxScore, .info]
        case .inProgress: [.playByPlay, .boxScore, .summary, .info]
        case .scheduled: [.preview, .info]
        }
    }

    /// Column titles for the quarter table: Q1–Q4, then OT, OT2… only when played.
    static func periodTitles(_ game: Game) -> [String] {
        let count = max(4, game.home.periodScores.count, game.away.periodScores.count)
        return (0..<count).map { index in
            index < 4 ? "Q\(index + 1)" : (index == 4 ? "OT" : "OT\(index - 3)")
        }
    }

    // MARK: Summary

    /// The player with the highest VAL on one side.
    static func topPerformer(_ box: TeamBoxScore?) -> PlayerBoxLine? {
        box?.players.max { ($0.stats.efficiency, -$0.rosterId) < ($1.stats.efficiency, -$1.rosterId) }
    }

    /// The best player per side in a stat (PTS, REB, AST).
    static func leader(_ box: TeamBoxScore?, _ stat: KeyPath<StatLine, Double>) -> PlayerBoxLine? {
        box?.players.max { ($0.stats[keyPath: stat], -$0.rosterId) < ($1.stats[keyPath: stat], -$1.rosterId) }
    }

    struct ComparisonRow: Identifiable, Hashable, Sendable {
        let id: String
        let title: String
        let home: Double
        let away: Double
        /// "6/13" for shooting rows.
        let homeDetail: String?
        let awayDetail: String?
        let isPercentage: Bool
        let lowerWins: Bool

        var better: ComparisonWinner {
            if home == away { return .neither }
            return (home > away) != lowerWins ? .home : .away
        }

        /// The home bar's share of the combined value, 0…1 (0.5 when both are 0).
        var homeShare: Double { home + away > 0 ? home / (home + away) : 0.5 }
    }

    /// FG, 3P, FT (made/attempted), REB, AST, STL, BLK, TOV (lower wins).
    static func comparison(home: StatLine, away: StatLine) -> [ComparisonRow] {
        func shooting(_ id: String, _ title: String, _ made: KeyPath<StatLine, Double>, _ attempted: KeyPath<StatLine, Double>) -> ComparisonRow {
            ComparisonRow(id: id, title: title,
                          home: StatLine.percentage(home[keyPath: made], home[keyPath: attempted]) ?? 0,
                          away: StatLine.percentage(away[keyPath: made], away[keyPath: attempted]) ?? 0,
                          homeDetail: Format.madeAttempted(home[keyPath: made], home[keyPath: attempted]),
                          awayDetail: Format.madeAttempted(away[keyPath: made], away[keyPath: attempted]),
                          isPercentage: true, lowerWins: false)
        }
        func count(_ id: String, _ title: String, _ stat: KeyPath<StatLine, Double>, lowerWins: Bool = false) -> ComparisonRow {
            ComparisonRow(id: id, title: title, home: home[keyPath: stat], away: away[keyPath: stat],
                          homeDetail: nil, awayDetail: nil, isPercentage: false, lowerWins: lowerWins)
        }
        return [
            shooting("fg", String(localized: "Field goals"), \.fieldGoalsMade, \.fieldGoalsAttempted),
            shooting("3p", String(localized: "3-pointers"), \.threePointersMade, \.threePointersAttempted),
            shooting("ft", String(localized: "Free throws"), \.freeThrowsMade, \.freeThrowsAttempted),
            count("reb", String(localized: "Rebounds"), \.rebounds),
            count("ast", String(localized: "Assists"), \.assists),
            count("stl", String(localized: "Steals"), \.steals),
            count("blk", String(localized: "Blocks"), \.blocks),
            count("tov", String(localized: "Turnovers"), \.turnovers, lowerWins: true)
        ]
    }

    // MARK: Preview

    /// A club's season so far, for the preview table.
    struct TeamForm: Hashable, Sendable {
        var pointsFor: Double?
        var pointsAgainst: Double?
        var rebounds: Double?
        var assists: Double?
        var fieldGoalPercentage: Double?
        var threePointPercentage: Double?
    }

    /// Team per-game numbers from the API's team averages plus its players' averages: each player's
    /// per-game line × games played gives season totals, divided by the club's games played.
    static func teamForm(statistics: TeamStatistics?, players: [PlayerSeasonAverages], gamesPlayed: Int) -> TeamForm {
        var totals = StatLine()
        for player in players { totals = totals.adding(player.perGame.scaled(by: Double(player.gamesPlayed))) }
        let hasPlayers = gamesPlayed > 0 && players.contains { $0.gamesPlayed > 0 }
        return TeamForm(pointsFor: statistics?.pointsFor,
                        pointsAgainst: statistics?.pointsAgainst,
                        rebounds: hasPlayers ? totals.rebounds / Double(gamesPlayed) : nil,
                        assists: hasPlayers ? totals.assists / Double(gamesPlayed) : nil,
                        fieldGoalPercentage: statistics?.fieldGoalPercentage ?? (hasPlayers ? totals.fieldGoalPercentage : nil),
                        threePointPercentage: hasPlayers ? totals.threePointPercentage : nil)
    }

    /// "Player to watch": the highest VAL per game among players who've played.
    static func playerToWatch(_ players: [PlayerSeasonAverages]) -> PlayerSeasonAverages? {
        players.filter { $0.gamesPlayed > 0 }.max { ($0.perGame.efficiency, -$0.rosterId) < ($1.perGame.efficiency, -$1.rosterId) }
    }

    /// Finished games between the two clubs this season, newest first, excluding this one.
    static func earlierMeetings(of game: Game, in games: [Game]) -> [Game] {
        let pair = Set([game.home.team.id, game.away.team.id])
        var seen = Set<Int>()
        return games
            .filter { $0.id != game.id && $0.status == .finished && Set([$0.home.team.id, $0.away.team.id]) == pair && seen.insert($0.id).inserted }
            .sorted { $0.tipOff > $1.tipOff }
    }

    // MARK: Info

    /// The official game page on bnxtleague.com.
    static func reportURL(gameId: Int) -> URL? { URL(string: "https://bnxtleague.com/en/game-report/\(gameId)") }

    static let watchURL = URL(string: "https://www.bnxt.tv/")

    /// "CET" or "CEST" at the tip-off date.
    static func zoneAbbreviation(at date: Date) -> String {
        GameTime.leagueTimeZone.isDaylightSavingTime(for: date) ? "CEST" : "CET"
    }
}
