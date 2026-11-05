import Foundation

/// A live game from the FIBA LiveStats feed (`…/data/{genius_id}/data.json`, REQUIREMENTS §7.4): clock, period,
/// score and play-by-play. Seen on 5 Nov 2026 (CHA–RCB): it changes about every 30 s while BNXT's own game
/// changes every ~3 min, so it drives the live screens. Optional by design: remote config can switch it off.
///
/// Privacy (§7.16): the feed also names coaches and officials and repeats players' names in several forms;
/// only the scoreboard name of the player in each play is decoded.
struct LiveFeed: Sendable, Equatable, Decodable {
    /// "07:42": time left in the period.
    let clock: String
    /// 1-based. In overtime (`periodType` "OVERTIME") the numbering is unconfirmed: see `periodLabel`.
    let period: Int
    let isOvertime: Bool
    /// Feed team 1 is the home side (BNXT `side` 1). The feed's codes differ from BNXT's ("ROT" vs "RCB"),
    /// so teams are matched by order, never by code.
    let homeScore: Int
    let awayScore: Int
    /// Points per period so far (Q1…, then overtimes): the quarter table, which BNXT leaves empty while live.
    let homePeriodScores: [Int]
    let awayPeriodScores: [Int]
    /// Player lines for the live box score (BNXT's stays empty while live).
    let homePlayers: [LivePlayerLine]
    let awayPlayers: [LivePlayerLine]
    /// Newest first, as the feed sends them.
    let plays: [LivePlay]

    private enum CodingKeys: String, CodingKey {
        case clock, period, periodType, inOT
        case teams = "tm", plays = "pbp"
    }

    init(clock: String, period: Int, isOvertime: Bool, homeScore: Int, awayScore: Int,
         homePeriodScores: [Int] = [], awayPeriodScores: [Int] = [], homePlayers: [LivePlayerLine] = [],
         awayPlayers: [LivePlayerLine] = [], plays: [LivePlay]) {
        self.clock = clock
        self.period = period
        self.isOvertime = isOvertime
        self.homeScore = homeScore
        self.awayScore = awayScore
        self.homePeriodScores = homePeriodScores
        self.awayPeriodScores = awayPeriodScores
        self.homePlayers = homePlayers
        self.awayPlayers = awayPlayers
        self.plays = plays
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clock = container.text(forKey: .clock) ?? ""
        period = container.integer(forKey: .period) ?? 0
        isOvertime = container.text(forKey: .periodType)?.uppercased() == "OVERTIME" || (container.integer(forKey: .inOT) ?? 0) > 0
        let teams = container.lenient([String: LiveFeedTeam].self, forKey: .teams) ?? [:]
        guard let home = teams["1"], let away = teams["2"] else {
            throw DecodingError.dataCorruptedError(forKey: .teams, in: container, debugDescription: "Live feed lacks team 1 or 2")
        }
        homeScore = home.score
        awayScore = away.score
        homePeriodScores = home.periodScores
        awayPeriodScores = away.periodScores
        homePlayers = home.players
        awayPlayers = away.players
        plays = container.lossyArray(LivePlay.self, forKey: .plays)
    }

    /// "Q3", "OT", "OT2": the period as the app labels it (regular periods are quarters).
    var periodLabel: String {
        guard period > 0 else { return "" }
        if isOvertime {
            // Not yet observed whether the feed restarts at 1 for overtime or continues at 5; accept both.
            let overtime = period > 4 ? period - 4 : period
            return overtime == 1 ? "OT" : "OT\(overtime)"
        }
        return "Q\(period)"
    }

    /// "Q3 07:42", shown next to LIVE.
    var statusText: String {
        [periodLabel, clock].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// The newest play worth a line on Home's live card: a made shot, or anything but substitutions and markers.
    var lastPlay: LivePlay? {
        plays.first { $0.kind.isNarrated }
    }
}

/// A team in the feed: its score, per-period scores (`p1_score`, `p2_score`, …) and player lines (`pl`). Coaches are never decoded (§7.16).
private struct LiveFeedTeam: Decodable {
    let score: Int
    let periodScores: [Int]
    let players: [LivePlayerLine]

    private struct Key: CodingKey {
        let stringValue: String
        init(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { nil }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        score = container.integer(forKey: Key(stringValue: "score")) ?? 0
        // `pl` is keyed by the feed's player number ("1", "14"…); order by it for a stable box score.
        let lines = container.lenient([String: Lenient<LivePlayerLine>].self, forKey: Key(stringValue: "pl")) ?? [:]
        players = lines.sorted { (Int($0.key) ?? 0) < (Int($1.key) ?? 0) }.compactMap(\.value.value)
        var periods: [Int: Int] = [:]
        for key in container.allKeys where key.stringValue.hasPrefix("p") && key.stringValue.hasSuffix("_score") {
            guard let number = Int(key.stringValue.dropFirst().dropLast("_score".count)), number > 0 else { continue }
            periods[number] = container.integer(forKey: key)
        }
        // Contiguous from period 1, so a gap never shifts a later period into an earlier column.
        periodScores = Array((1...max(periods.keys.max() ?? 0, 1)).prefix { periods[$0] != nil }.compactMap { periods[$0] })
    }
}

/// Decodes to nil instead of failing, so one odd player line never drops the team.
private struct Lenient<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
}

/// One player's line in the feed (`tm.*.pl`). Only the scoreboard name, number and stats are decoded: the feed's
/// first, family and international names are not (§7.16).
struct LivePlayerLine: Hashable, Sendable, Decodable {
    /// "J. Heath", as `Player.shortName` writes it: used to find the player's roster entry.
    let scoreboardName: String
    let jersey: String?
    let isStarter: Bool
    let stats: StatLine

    private enum CodingKeys: String, CodingKey {
        case scoreboardName, shirtNumber, starter, sMinutes, sPoints, sReboundsTotal, sReboundsOffensive, sReboundsDefensive
        case sAssists, sSteals, sBlocks, sTurnovers, sFoulsPersonal, sFoulsOn, sPlusMinusPoints
        case sFieldGoalsMade, sFieldGoalsAttempted, sTwoPointersMade, sTwoPointersAttempted
        case sThreePointersMade, sThreePointersAttempted, sFreeThrowsMade, sFreeThrowsAttempted
    }

    init(scoreboardName: String, jersey: String?, isStarter: Bool, stats: StatLine) {
        self.scoreboardName = scoreboardName
        self.jersey = jersey
        self.isStarter = isStarter
        self.stats = stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let name = container.text(forKey: .scoreboardName) else {
            throw DecodingError.dataCorruptedError(forKey: .scoreboardName, in: container, debugDescription: "No scoreboard name")
        }
        scoreboardName = name
        jersey = container.text(forKey: .shirtNumber)
        isStarter = (container.integer(forKey: .starter) ?? 0) == 1
        func value(_ key: CodingKeys) -> Double { container.number(forKey: key) ?? 0 }
        var stats = StatLine()
        stats.minutes = Self.minutes(container.text(forKey: .sMinutes))
        stats.points = value(.sPoints)
        stats.rebounds = value(.sReboundsTotal)
        stats.offensiveRebounds = value(.sReboundsOffensive)
        stats.defensiveRebounds = value(.sReboundsDefensive)
        stats.assists = value(.sAssists)
        stats.steals = value(.sSteals)
        stats.blocks = value(.sBlocks)
        stats.turnovers = value(.sTurnovers)
        stats.fouls = value(.sFoulsPersonal)
        stats.fieldGoalsMade = value(.sFieldGoalsMade)
        stats.fieldGoalsAttempted = value(.sFieldGoalsAttempted)
        stats.twoPointersMade = value(.sTwoPointersMade)
        stats.twoPointersAttempted = value(.sTwoPointersAttempted)
        stats.threePointersMade = value(.sThreePointersMade)
        stats.threePointersAttempted = value(.sThreePointersAttempted)
        stats.freeThrowsMade = value(.sFreeThrowsMade)
        stats.freeThrowsAttempted = value(.sFreeThrowsAttempted)
        stats.plusMinus = container.number(forKey: .sPlusMinusPoints)
        stats.efficiency = Self.efficiency(stats, foulsDrawn: value(.sFoulsOn))
        self.stats = stats
    }

    /// "14:35" → 14.58 minutes (box scores floor it to 14).
    static func minutes(_ text: String?) -> Double {
        let parts = (text ?? "").split(separator: ":").compactMap { Double($0) }
        guard let whole = parts.first else { return 0 }
        return whole + (parts.count > 1 ? parts[1] / 60 : 0)
    }

    /// BNXT's VAL, checked against its own box scores (game 11323): PTS + REB + AST + STL + BLK + fouls drawn
    /// − missed field goals − missed free throws − turnovers. Personal fouls and blocks received don't count, and none of
    /// the feed's `eff_*` values matches it for every player, so it's computed here.
    static func efficiency(_ line: StatLine, foulsDrawn: Double) -> Double {
        line.points + line.rebounds + line.assists + line.steals + line.blocks + foulsDrawn
            - (line.fieldGoalsAttempted - line.fieldGoalsMade) - (line.freeThrowsAttempted - line.freeThrowsMade) - line.turnovers
    }

    /// Played in this game: on the floor at some point, or started.
    var hasPlayed: Bool { stats.minutes > 0 || isStarter }
}

/// The live box score built from the feed (§3.4): BNXT's own stays empty while a game is live.
enum LiveBoxScore {
    /// Both teams' lines, players matched to their roster entries by scoreboard name so rows open the player page.
    /// A player the rosters don't have gets a negative placeholder id, and their row doesn't open anything.
    static func make(_ feed: LiveFeed, game: Game, rosters: [Int: [RosterEntry]]) -> BoxScore {
        func team(_ side: GameSide, lines: [LivePlayerLine], isHome: Bool) -> TeamBoxScore {
            let entries = rosters[side.team.id] ?? []
            var players: [PlayerBoxLine] = []
            for (index, line) in lines.enumerated() where line.hasPlayed {
                let entry = entries.first {
                    $0.player.shortName.compare(line.scoreboardName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
                }
                let placeholder = -((isHome ? 1000 : 2000) + index)
                players.append(PlayerBoxLine(rosterId: entry?.id ?? placeholder,
                                             player: entry?.player ?? Player(id: placeholder, firstName: "", lastName: line.scoreboardName),
                                             position: entry?.position, isStarter: line.isStarter, jersey: line.jersey, stats: line.stats))
            }
            let totals = players.reduce(StatLine()) { $0.adding($1.stats) }
            return TeamBoxScore(team: side.team, isHome: isHome, players: players, totals: totals)
        }
        return BoxScore(teams: [team(game.home, lines: feed.homePlayers, isHome: true),
                                team(game.away, lines: feed.awayPlayers, isHome: false)])
    }
}

/// One play-by-play entry.
struct LivePlay: Identifiable, Hashable, Sendable, Decodable {
    enum Kind: Hashable, Sendable {
        case twoPointer, threePointer, freeThrow, rebound, assist, steal, block, turnover, foul, timeout
        /// Substitutions, jump balls, period and game markers, fouls drawn: not shown as plays.
        case other(String)

        private static let byActionType: [String: Kind] = [
            "2pt": .twoPointer, "3pt": .threePointer, "freethrow": .freeThrow, "rebound": .rebound, "assist": .assist,
            "steal": .steal, "block": .block, "turnover": .turnover, "foul": .foul, "timeout": .timeout
        ]

        init(_ raw: String) {
            self = Self.byActionType[raw.lowercased()] ?? .other(raw)
        }

        var isNarrated: Bool {
            if case .other = self { return false }
            return true
        }

        var points: Int {
            switch self {
            case .twoPointer: 2
            case .threePointer: 3
            case .freeThrow: 1
            default: 0
            }
        }
    }

    /// The feed's running action number; unique within a game.
    let id: Int
    /// "07:42" in the period.
    let clock: String
    let period: Int
    let isOvertime: Bool
    /// 1 = home, 2 = away, nil for game events (timeouts by the officials, period markers).
    let side: Int?
    /// "J. Heath"; nil for team plays.
    let playerName: String?
    let kind: Kind
    /// For shots: whether it went in. The feed marks every shot `scoring: 1`, made or missed.
    let made: Bool
    let homeScore: Int
    let awayScore: Int

    /// A made shot or free throw: the line shows the score after it (§3.4).
    var isScore: Bool { kind.points > 0 && made }

    private enum CodingKeys: String, CodingKey {
        case actionNumber, period, periodType, scoreboardName, player, actionType, success
        case gameClock = "gt", team = "tno", homeScore = "s1", awayScore = "s2"
    }

    init(id: Int, clock: String, period: Int, isOvertime: Bool = false, side: Int?, playerName: String?, kind: Kind,
         made: Bool, homeScore: Int, awayScore: Int) {
        self.id = id
        self.clock = clock
        self.period = period
        self.isOvertime = isOvertime
        self.side = side
        self.playerName = playerName
        self.kind = kind
        self.made = made
        self.homeScore = homeScore
        self.awayScore = awayScore
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.requiredInteger(forKey: .actionNumber)
        clock = container.text(forKey: .gameClock) ?? ""
        period = container.integer(forKey: .period) ?? 0
        isOvertime = container.text(forKey: .periodType)?.uppercased() == "OVERTIME"
        side = container.integer(forKey: .team).flatMap { (1...2).contains($0) ? $0 : nil }
        playerName = container.text(forKey: .scoreboardName) ?? container.text(forKey: .player)
        kind = Kind(container.text(forKey: .actionType) ?? "")
        made = (container.integer(forKey: .success) ?? 0) == 1
        homeScore = container.integer(forKey: .homeScore) ?? 0
        awayScore = container.integer(forKey: .awayScore) ?? 0
    }

    /// "3PT made", "Free throw missed", "Rebound": what happened, without the player.
    var description: String {
        switch kind {
        case .twoPointer: outcome(String(localized: "2PT made"), String(localized: "2PT missed"))
        case .threePointer: outcome(String(localized: "3PT made"), String(localized: "3PT missed"))
        case .freeThrow: outcome(String(localized: "Free throw made"), String(localized: "Free throw missed"))
        case .rebound: String(localized: "Rebound")
        case .assist: String(localized: "Assist")
        case .steal: String(localized: "Steal")
        case .block: String(localized: "Block")
        case .turnover: String(localized: "Turnover")
        case .foul: String(localized: "Foul")
        case .timeout: String(localized: "Timeout")
        case let .other(raw): raw
        }
    }

    private func outcome(_ madeText: String, _ missedText: String) -> String {
        if made { return madeText }
        return missedText
    }

    /// "J. Heath · 3PT made".
    var line: String {
        [playerName, description].compactMap { $0 }.joined(separator: " · ")
    }
}

/// The FIBA LiveStats client (§7.4). No key, no cache: a stale live score is worse than none, and the
/// screens fall back to BNXT's own score when this fails.
struct LiveStatsClient: Sendable {
    let baseURL: URL
    let session: URLSession

    init(baseURL: URL = APIConfiguration.defaultLiveStatsURL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func feed(geniusId: Int) async throws -> LiveFeed {
        let url = baseURL.appending(path: "\(geniusId)/data.json")
        let (data, response) = try await session.data(for: URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        do {
            return try JSONDecoder().decode(LiveFeed.self, from: data)
        } catch {
            throw APIError.decoding(endpoint: "livestats/\(geniusId)", message: String(describing: error))
        }
    }
}

extension Game {
    /// The game with the live feed's score and "Q3 07:42" as its period, so headers and rows show them unchanged.
    func applying(_ feed: LiveFeed) -> Game {
        Game(id: id, tipOff: tipOff, status: status,
             home: GameSide(team: home.team, score: feed.homeScore,
                            periodScores: feed.homePeriodScores.isEmpty ? home.periodScores : feed.homePeriodScores),
             away: GameSide(team: away.team, score: feed.awayScore,
                            periodScores: feed.awayPeriodScores.isEmpty ? away.periodScores : feed.awayPeriodScores),
             period: feed.statusText.isEmpty ? period : feed.statusText, arena: arena, geniusId: geniusId, phaseId: phaseId,
             teamTotals: teamTotals)
    }
}
