import Foundation

/// `boxscore/game/{cid}/{game}`: one entry per team.
struct BoxScore: Hashable, Sendable, Decodable {
    let teams: [TeamBoxScore]

    var home: TeamBoxScore? { teams.first(where: \.isHome) }
    var away: TeamBoxScore? { teams.first { !$0.isHome } }

    /// No player lines yet (before or early in a game). An empty cached box score isn't trusted.
    var isEmpty: Bool { teams.allSatisfy(\.players.isEmpty) }

    init(teams: [TeamBoxScore]) {
        self.teams = teams
    }

    init(from decoder: Decoder) throws {
        teams = try LossyArray<TeamBoxScore>(from: decoder).elements
    }
}

struct TeamBoxScore: Hashable, Sendable, Decodable {
    let team: Team
    let isHome: Bool
    let players: [PlayerBoxLine]
    let totals: StatLine

    init(team: Team, isHome: Bool, players: [PlayerBoxLine], totals: StatLine) {
        self.team = team
        self.isHome = isHome
        self.players = players
        self.totals = totals
    }

    private enum CodingKeys: String, CodingKey {
        case team, players
        case isHome = "is_home"
        case totals = "total"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        team = try container.decode(Team.self, forKey: .team)
        isHome = container.lenient(Bool.self, forKey: .isHome) ?? false
        players = container.lossyArray(PlayerBoxLine.self, forKey: .players)
        totals = container.lenient(StatLine.self, forKey: .totals) ?? .zero
    }
}

/// One player's line in a game.
struct PlayerBoxLine: Identifiable, Hashable, Sendable, Decodable {
    var id: Int { rosterId }
    let rosterId: Int
    let player: Player
    let position: PlayingPosition?
    let isStarter: Bool
    let jersey: String?
    let stats: StatLine

    init(rosterId: Int, player: Player, position: PlayingPosition? = nil, isStarter: Bool, jersey: String?, stats: StatLine) {
        self.rosterId = rosterId
        self.player = player
        self.position = position
        self.isStarter = isStarter
        self.jersey = jersey
        self.stats = stats
    }

    private enum CodingKeys: String, CodingKey {
        case player, position, jersey
        case rosterId = "roster_id"
        case isStarter = "starter"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rosterId = try container.requiredInteger(forKey: .rosterId)
        player = try container.decode(Player.self, forKey: .player)
        position = container.lenient(PlayingPosition.self, forKey: .position)
        isStarter = container.lenient(Bool.self, forKey: .isStarter) ?? false
        jersey = container.text(forKey: .jersey)
        stats = try StatLine(from: decoder)
    }
}

/// One game in a player's season (`boxscore/player/season-games/{rosterId}`).
struct PlayerGameLine: Identifiable, Hashable, Sendable, Decodable {
    var id: Int { game.id }
    let game: Game
    let teamId: Int
    let isStarter: Bool
    let jersey: String?
    let stats: StatLine

    private enum CodingKeys: String, CodingKey {
        case game, jersey
        case teamId = "competition_team_id"
        case isStarter = "starter"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        game = try container.decode(Game.self, forKey: .game)
        teamId = container.integer(forKey: .teamId) ?? 0
        isStarter = container.lenient(Bool.self, forKey: .isStarter) ?? false
        jersey = container.text(forKey: .jersey)
        stats = try StatLine(from: decoder)
    }
}
