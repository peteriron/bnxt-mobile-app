import Foundation

/// One row of `standings/competition/{cid}/phase/{phase}`.
struct Standing: Identifiable, Hashable, Sendable, Decodable {
    var id: Int { team.id }
    let team: Team
    let position: Int
    let played: Int
    let wins: Int
    let losses: Int
    let pointsFor: Int
    let pointsAgainst: Int
    let pointDifference: Int
    let home: WinLoss
    let away: WinLoss
    let lastFive: WinLoss
    let streak: Streak?

    private enum CodingKeys: String, CodingKey {
        case team, position, played, streak
        case wins = "win", losses = "loss"
        case pointsFor = "score", pointsAgainst = "against"
        case pointDifference = "score_difference"
        case homeAway = "win_loss"
        case lastFive = "last5"
    }

    private struct HomeAway: Decodable {
        let home: WinLoss?
        let away: WinLoss?
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        team = try container.decode(Team.self, forKey: .team)
        position = try container.requiredInteger(forKey: .position)
        wins = container.integer(forKey: .wins) ?? 0
        losses = container.integer(forKey: .losses) ?? 0
        played = container.integer(forKey: .played) ?? (wins + losses)
        pointsFor = container.integer(forKey: .pointsFor) ?? 0
        pointsAgainst = container.integer(forKey: .pointsAgainst) ?? 0
        pointDifference = container.integer(forKey: .pointDifference) ?? (pointsFor - pointsAgainst)
        let homeAway = container.lenient(HomeAway.self, forKey: .homeAway)
        home = homeAway?.home ?? .zero
        away = homeAway?.away ?? .zero
        lastFive = container.lenient(WinLoss.self, forKey: .lastFive) ?? .zero
        streak = container.lenient(Streak.self, forKey: .streak)
    }
}

struct WinLoss: Hashable, Sendable, Decodable {
    let wins: Int
    let losses: Int

    static let zero = WinLoss(wins: 0, losses: 0)

    private enum CodingKeys: String, CodingKey { case wins = "win", losses = "loss" }

    init(wins: Int, losses: Int) {
        self.wins = wins
        self.losses = losses
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(wins: container.integer(forKey: .wins) ?? 0, losses: container.integer(forKey: .losses) ?? 0)
    }
}

struct Streak: Hashable, Sendable, Decodable {
    let isWinning: Bool
    let count: Int

    private enum CodingKeys: String, CodingKey { case isWinning = "is_win", count }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isWinning = container.lenient(Bool.self, forKey: .isWinning) ?? false
        count = container.integer(forKey: .count) ?? 0
    }
}
