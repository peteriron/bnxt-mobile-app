import Foundation

/// A game from `schedule/find`, `schedule/game-slider` or a team's game list.
struct Game: Identifiable, Hashable, Sendable, Decodable {
    let id: Int
    let tipOff: Date
    let status: GameStatus
    let home: GameSide
    let away: GameSide
    /// "Q4"; absent before tip-off.
    let period: String?
    /// Only `schedule/find` and team game lists send the arena.
    let arena: String?
    /// The FIBA LiveStats id (only the game slider sends it; REQUIREMENTS §7.4).
    let geniusId: Int?
    let phaseId: Int?
    /// The requesting club's own totals for this game. Only team game lists (`statistics-by-game/total/{team}`) send it;
    /// the Stats tab's team table is built from it (§3.6).
    let teamTotals: StatLine?

    var hasStarted: Bool { status != .scheduled }

    /// The winning team of a finished game; nil otherwise or on a tie.
    var winner: Team? {
        guard status == .finished, let homeScore = home.score, let awayScore = away.score, homeScore != awayScore else { return nil }
        return homeScore > awayScore ? home.team : away.team
    }

    init(id: Int, tipOff: Date, status: GameStatus, home: GameSide, away: GameSide, period: String? = nil,
         arena: String? = nil, geniusId: Int? = nil, phaseId: Int? = nil, teamTotals: StatLine? = nil) {
        self.id = id
        self.tipOff = tipOff
        self.status = status
        self.home = home
        self.away = away
        self.period = period
        self.arena = arena
        self.geniusId = geniusId
        self.phaseId = phaseId
        self.teamTotals = teamTotals
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, competitors, period, arena, phase, total
        case tipOff = "game_time"
        case geniusId = "genius_id"
    }

    private struct Named: Decodable { let name: String? }
    private struct Identified: Decodable { let id: Int }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.requiredInteger(forKey: .id)
        let time = try container.requiredText(forKey: .tipOff)
        guard let tipOff = GameTime.parse(time) else {
            throw DecodingError.dataCorruptedError(forKey: .tipOff, in: container, debugDescription: "Unparsable game_time \(time)")
        }
        self.tipOff = tipOff
        status = GameStatus(raw: container.text(forKey: .status) ?? "")
        // side 1 = home, side 2 = away (confirmed against the box score's is_home).
        let competitors = container.lossyArray(Competitor.self, forKey: .competitors)
        guard let home = competitors.first(where: { $0.side == 1 }), let away = competitors.first(where: { $0.side == 2 }) else {
            throw DecodingError.dataCorruptedError(forKey: .competitors, in: container, debugDescription: "Game \(id) lacks a home or away side")
        }
        // Before tip-off the API sends finalScore 0 and no quarters; that isn't a score.
        let started = status != .scheduled
        self.home = home.side(started: started)
        self.away = away.side(started: started)
        period = container.lenient(Named.self, forKey: .period)?.name.flatMap { $0.isEmpty ? nil : $0 }
        arena = container.lenient(Named.self, forKey: .arena)?.name.flatMap { $0.isEmpty ? nil : $0 }
        geniusId = container.integer(forKey: .geniusId)
        phaseId = container.lenient(Identified.self, forKey: .phase)?.id
        teamTotals = container.lenient(StatLine.self, forKey: .total)
    }
}

enum GameStatus: Hashable, Sendable {
    case scheduled
    case finished
    /// Any other value. The API's live status hasn't been observed yet (REQUIREMENTS §7.4), so it's kept raw.
    case inProgress(raw: String)

    init(raw: String) {
        switch raw.lowercased() {
        case "ready", "": self = .scheduled
        case "finished": self = .finished
        default: self = .inProgress(raw: raw)
        }
    }
}

struct GameSide: Hashable, Sendable {
    let team: Team
    /// nil before tip-off.
    let score: Int?
    /// Points per period in order (Q1…Q4, then overtimes); empty before tip-off.
    let periodScores: [Int]
}

/// One element of a game's `competitors` array.
private struct Competitor: Decodable {
    let side: Int
    let finalScore: Int?
    let team: Team
    let periods: [CompetitorPeriod]

    private enum CodingKeys: String, CodingKey {
        case side, finalScore
        case team = "competition_team"
        case periods = "period_scores"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        side = try container.requiredInteger(forKey: .side)
        finalScore = container.integer(forKey: .finalScore)
        team = try container.decode(Team.self, forKey: .team)
        periods = container.lossyArray(CompetitorPeriod.self, forKey: .periods).sorted { $0.number < $1.number }
    }

    func side(started: Bool) -> GameSide {
        GameSide(team: team, score: started ? finalScore : nil, periodScores: started ? periods.map(\.score) : [])
    }
}

/// One entry of a competitor's `period_scores`.
private struct CompetitorPeriod: Decodable {
    let number: Int
    let score: Int

    private enum CodingKeys: String, CodingKey { case number = "period_id", score }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.requiredInteger(forKey: .number)
        score = container.integer(forKey: .score) ?? 0
    }
}
