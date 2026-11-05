import Foundation

/// The stat block the API uses everywhere: box-score lines and totals, per-game averages, game-log lines.
/// Field mapping (docs/bnxt-api.md): `throw_*` are **field goals**, `free_throw_*` free throws, `value` is VAL/PIR.
/// Missing or null numbers decode as 0, except `plusMinus` (absent in game logs, often 0 in box scores).
struct StatLine: Hashable, Sendable, Decodable {
    var minutes: Double = 0
    var points: Double = 0
    var twoPointersMade: Double = 0
    var twoPointersAttempted: Double = 0
    var threePointersMade: Double = 0
    var threePointersAttempted: Double = 0
    var fieldGoalsMade: Double = 0
    var fieldGoalsAttempted: Double = 0
    var freeThrowsMade: Double = 0
    var freeThrowsAttempted: Double = 0
    var offensiveRebounds: Double = 0
    var defensiveRebounds: Double = 0
    var rebounds: Double = 0
    var assists: Double = 0
    var steals: Double = 0
    var blocks: Double = 0
    var turnovers: Double = 0
    var fouls: Double = 0
    var efficiency: Double = 0
    var plusMinus: Double?

    static let zero = StatLine()

    var fieldGoalPercentage: Double? { Self.percentage(fieldGoalsMade, fieldGoalsAttempted) }
    var twoPointPercentage: Double? { Self.percentage(twoPointersMade, twoPointersAttempted) }
    var threePointPercentage: Double? { Self.percentage(threePointersMade, threePointersAttempted) }
    var freeThrowPercentage: Double? { Self.percentage(freeThrowsMade, freeThrowsAttempted) }

    /// nil when nothing was attempted, so 0/0 never shows as "0 %".
    static func percentage(_ made: Double, _ attempted: Double) -> Double? {
        attempted > 0 ? 100 * made / attempted : nil
    }

    private enum CodingKeys: String, CodingKey {
        case minutes = "minute", points, assists = "assist", steals = "steal", blocks = "block"
        case twoPointersMade = "two_point_made", twoPointersAttempted = "two_point_all"
        case threePointersMade = "three_point_made", threePointersAttempted = "three_point_all"
        case fieldGoalsMade = "throw_made", fieldGoalsAttempted = "throw_all"
        case freeThrowsMade = "free_throw_made", freeThrowsAttempted = "free_throw_all"
        case offensiveRebounds = "offensive_rebound", defensiveRebounds = "defensive_rebound", rebounds = "total_rebound"
        case turnovers = "turnover", fouls = "foul", efficiency = "value", plusMinus = "plusminus"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value(_ key: CodingKeys) -> Double { container.number(forKey: key) ?? 0 }
        minutes = value(.minutes)
        points = value(.points)
        twoPointersMade = value(.twoPointersMade)
        twoPointersAttempted = value(.twoPointersAttempted)
        threePointersMade = value(.threePointersMade)
        threePointersAttempted = value(.threePointersAttempted)
        fieldGoalsMade = value(.fieldGoalsMade)
        fieldGoalsAttempted = value(.fieldGoalsAttempted)
        freeThrowsMade = value(.freeThrowsMade)
        freeThrowsAttempted = value(.freeThrowsAttempted)
        offensiveRebounds = value(.offensiveRebounds)
        defensiveRebounds = value(.defensiveRebounds)
        rebounds = value(.rebounds)
        assists = value(.assists)
        steals = value(.steals)
        blocks = value(.blocks)
        turnovers = value(.turnovers)
        fouls = value(.fouls)
        efficiency = value(.efficiency)
        plusMinus = container.number(forKey: .plusMinus)
    }
}

/// A player's per-game season averages for one team (`competition-team/player-averages/{team}`).
struct PlayerSeasonAverages: Identifiable, Hashable, Sendable, Decodable {
    var id: Int { rosterId }
    let rosterId: Int
    let player: Player
    let gamesPlayed: Int
    let gamesStarted: Int
    let perGame: StatLine

    private enum CodingKeys: String, CodingKey {
        case player
        case rosterId = "roster_id"
        case gamesPlayed = "played_games"
        case gamesStarted = "starter"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rosterId = try container.requiredInteger(forKey: .rosterId)
        player = try container.decode(Player.self, forKey: .player)
        gamesPlayed = container.integer(forKey: .gamesPlayed) ?? 0
        gamesStarted = container.integer(forKey: .gamesStarted) ?? 0
        perGame = try StatLine(from: decoder)
    }
}
