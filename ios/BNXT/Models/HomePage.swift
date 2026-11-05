import Foundation

/// Pure rules for the club-centric Home (§3.2), ported from the prototype's `VIEWS.home`.
enum HomePage {
    // MARK: Games

    /// The favourite club's game in progress, if any.
    static func liveGame(_ games: [Game], clubId: Int) -> Game? {
        games.filter { $0.isLive && $0.involves(clubId) }.min { $0.tipOff < $1.tipOff }
    }

    /// The club's next scheduled game.
    static func nextGame(_ games: [Game], clubId: Int) -> Game? {
        games.filter { $0.status == .scheduled && $0.involves(clubId) }.min { ($0.tipOff, $0.id) < ($1.tipOff, $1.id) }
    }

    /// The club's most recent finished game.
    static func lastResult(_ games: [Game], clubId: Int) -> Game? {
        games.filter { $0.status == .finished && $0.involves(clubId) }.max { ($0.tipOff, $0.id) < ($1.tipOff, $1.id) }
    }

    /// Calendar days from `now` to `date` in league time (0 = today).
    static func daysUntil(_ date: Date, now: Date) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GameTime.leagueTimeZone
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
    }

    /// "Today", "Tomorrow", "In 5 days".
    static func countdown(to date: Date, now: Date) -> String {
        switch daysUntil(date, now: now) {
        case ...0: String(localized: "Today")
        case 1: String(localized: "Tomorrow")
        case let days: String(localized: "In \(days) days")
        }
    }

    /// How many days back from the latest result "Around the league" reaches: the last 4 days with results (prototype).
    static let roundDays = 4

    /// Results of the most recent round: finished games from the latest result's day and the 3 days before, newest first.
    static func aroundTheLeague(_ games: [Game]) -> [Game] {
        let finished = Dictionary(games.filter { $0.status == .finished }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        guard let latest = finished.map(\.tipOff).max() else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GameTime.leagueTimeZone
        guard let from = calendar.date(byAdding: .day, value: -(roundDays - 1), to: calendar.startOfDay(for: latest)) else { return [] }
        return finished.filter { $0.tipOff >= from }.sorted { ($0.tipOff, $0.id) > ($1.tipOff, $1.id) }
    }

    // MARK: Standing

    enum PlayoffStatus: Hashable, Sendable {
        /// First in the league table.
        case leader
        /// Inside the club's national playoff zone.
        case playoffPlace
        case outside
        /// The config has no zone for the club's country.
        case unknown
    }

    struct StandingSummary: Hashable, Sendable {
        let standing: Standing
        let country: Country?
        let nationalRank: Int?
        let playoffStatus: PlayoffStatus
        /// Five league rows centred on the club (fewer when the table is shorter).
        let snippet: [StandingsTable.Row]
    }

    static let snippetSize = 5

    static func standing(_ table: StandingsTable, clubId: Int) -> StandingSummary? {
        let rows = table.rows(for: .league)
        guard let index = rows.firstIndex(where: { $0.standing.team.id == clubId }) else { return nil }
        let standing = rows[index].standing
        let country = table.country(of: standing)
        let nationalRank = table.nationalRank(of: clubId)
        let status: PlayoffStatus
        if standing.position == 1 {
            status = .leader
        } else if let country, let cut = table.cutLine(for: .country(country)), let nationalRank {
            status = nationalRank <= cut ? .playoffPlace : .outside
        } else {
            status = .unknown
        }
        let start = max(0, min(index - snippetSize / 2, rows.count - snippetSize))
        return StandingSummary(standing: standing, country: country, nationalRank: nationalRank, playoffStatus: status,
                               snippet: Array(rows[start..<min(start + snippetSize, rows.count)]))
    }

    // MARK: Leaders

    enum LeaderStat: String, CaseIterable, Identifiable, Sendable {
        case points = "PTS", rebounds = "REB", assists = "AST", efficiency = "VAL"

        var id: Self { self }

        var keyPath: KeyPath<StatLine, Double> {
            switch self {
            case .points: \.points
            case .rebounds: \.rebounds
            case .assists: \.assists
            case .efficiency: \.efficiency
            }
        }
    }

    struct ClubLeader: Identifiable, Hashable, Sendable {
        var id: LeaderStat { stat }
        let stat: LeaderStat
        let player: PlayerSeasonAverages
        var value: Double { player.perGame[keyPath: stat.keyPath] }
    }

    /// The club's top player per stat (per-game averages), among players who've played. Ties go to the lower roster id.
    static func clubLeaders(_ averages: [PlayerSeasonAverages]) -> [ClubLeader] {
        let played = averages.filter { $0.gamesPlayed > 0 }
        return LeaderStat.allCases.compactMap { stat in
            played.max { ($0.perGame[keyPath: stat.keyPath], -$0.rosterId) < ($1.perGame[keyPath: stat.keyPath], -$1.rosterId) }
                .map { ClubLeader(stat: stat, player: $0) }
        }
    }

    static let leagueLeaderCount = 3

    /// League VAL top 3 (§3.2), in the league's order.
    static func leagueLeaders(_ leaders: PlayerLeaders?) -> [LeaderEntry] {
        Array((leaders?[.efficiency] ?? []).prefix(leagueLeaderCount))
    }
}
