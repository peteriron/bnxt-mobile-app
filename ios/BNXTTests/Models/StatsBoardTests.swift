@testable import BNXT
import XCTest

/// §3.6: team stats summed from team game lists, and the rankings the Stats tab shows.
final class StatsBoardTests: XCTestCase {
    private func game(id: Int, // swiftlint:disable:this function_parameter_count
                      home: Int, away: Int, homeScore: Int?, awayScore: Int?, status: GameStatus = .finished,
                      phase: Int? = 183, totals: StatLine?) -> Game {
        Game(id: id, tipOff: Date(timeIntervalSince1970: TimeInterval(id)), status: status,
             home: GameSide(team: Team(id: home, name: "H", shortName: "H"), score: homeScore, periodScores: []),
             away: GameSide(team: Team(id: away, name: "A", shortName: "A"), score: awayScore, periodScores: []),
             phaseId: phase, teamTotals: totals)
    }

    private func line(rebounds: Double = 0, turnovers: Double = 0, fgm: Double = 0, fga: Double = 0) -> StatLine {
        var line = StatLine()
        line.rebounds = rebounds
        line.turnovers = turnovers
        line.fieldGoalsMade = fgm
        line.fieldGoalsAttempted = fga
        return line
    }

    // MARK: Decoding

    func testTeamGamesCarryTheRequestingClubsTotals() throws {
        let games = try Fixture.list(Game.self, from: "team_games_537")
        XCTAssertEqual(games.count, 5)
        let first = try XCTUnwrap(games.first { $0.id == 11279 })
        // LEU 69 – CHA 65: the totals are Spirou's (537), not the home side's.
        XCTAssertEqual(first.teamTotals?.points, 65)
        XCTAssertEqual(first.teamTotals?.rebounds, 42)
    }

    func testOtherGamePayloadsHaveNoTeamTotals() throws {
        XCTAssertNil(try Fixture.decode(Envelope<Game>.self, from: "game_11323").data.teamTotals)
    }

    // MARK: Team season

    func testSeasonFromTheFixture() throws {
        let games = try Fixture.list(Game.self, from: "team_games_537")
        let stats = try XCTUnwrap(TeamSeasonStats.from(games, teamId: 537, phaseIds: [183]))
        XCTAssertEqual(stats.games, 5)
        // 65 + 98 + 90 + 65 + 81 scored; 69 + 60 + 63 + 70 + 66 allowed.
        XCTAssertEqual(try XCTUnwrap(stats.value(.points)), 79.8, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(stats.value(.pointsAllowed)), 65.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(stats.value(.rebounds)), 41.0, accuracy: 0.001)
    }

    func testPercentagesAreOverTheSeasonsAttemptsNotAnAverageOfGames() throws {
        let games = [game(id: 1, home: 1, away: 2, homeScore: 80, awayScore: 70, totals: line(fgm: 1, fga: 10)),
                     game(id: 2, home: 2, away: 1, homeScore: 70, awayScore: 80, totals: line(fgm: 30, fga: 30))]
        let stats = try XCTUnwrap(TeamSeasonStats.from(games, teamId: 1, phaseIds: [183]))
        XCTAssertEqual(try XCTUnwrap(stats.value(.fieldGoalPercentage)), 77.5, accuracy: 0.001, "31/40, not (10% + 100%) / 2")
    }

    func testSkipsUnfinishedOtherPhaseAndTotallessGames() {
        let games = [game(id: 1, home: 1, away: 2, homeScore: nil, awayScore: nil, status: .scheduled, totals: line()),
                     game(id: 2, home: 1, away: 2, homeScore: 80, awayScore: 70, phase: 999, totals: line()),
                     game(id: 3, home: 1, away: 2, homeScore: 80, awayScore: 70, totals: nil),
                     game(id: 4, home: 3, away: 4, homeScore: 80, awayScore: 70, totals: line())]
        XCTAssertNil(TeamSeasonStats.from(games, teamId: 1, phaseIds: [183]))
    }

    func testNoAttemptsMeansNoPercentage() throws {
        let stats = try XCTUnwrap(TeamSeasonStats.from([game(id: 1, home: 1, away: 2, homeScore: 1, awayScore: 0, totals: line())],
                                                       teamId: 1, phaseIds: [183]))
        XCTAssertNil(stats.value(.threePointPercentage))
    }

    // MARK: Rankings

    private func season(team: Int, rebounds: Double, turnovers: Double) -> TeamSeasonStats {
        var totals = StatLine()
        totals.rebounds = rebounds
        totals.turnovers = turnovers
        return TeamSeasonStats(teamId: team, games: 1, totals: totals, pointsScored: 0, pointsAllowed: 0)
    }

    func testTeamsRankBestFirstAndTurnoversAscend() {
        let stats = [season(team: 1, rebounds: 30, turnovers: 15), season(team: 2, rebounds: 40, turnovers: 10),
                     season(team: 3, rebounds: 35, turnovers: 12)]
        XCTAssertEqual(StatsBoard.teamRows(stats, category: .rebounds).map(\.teamId), [2, 3, 1])
        XCTAssertEqual(StatsBoard.teamRows(stats, category: .turnovers).map(\.teamId), [2, 3, 1], "lower is better")
        XCTAssertEqual(StatsBoard.teamRows(stats, category: .turnovers).map(\.rank), [1, 2, 3])
    }

    func testTeamBarsRunFromAStubToFull() {
        let stats = [season(team: 1, rebounds: 30, turnovers: 0), season(team: 2, rebounds: 40, turnovers: 0),
                     season(team: 3, rebounds: 35, turnovers: 0)]
        let rows = StatsBoard.teamRows(stats, category: .rebounds)
        for (fraction, expected) in zip(rows.map(\.fraction), [1, 0.6, 0.2]) { XCTAssertEqual(fraction, expected, accuracy: 1e-9) }
        XCTAssertEqual(StatsBoard.teamRows(stats, category: .turnovers).map(\.fraction), [1, 1, 1], "all equal: full bars")
    }

    func testPlayerRowsFollowTheLeaguesOrderWithBarsRelativeToTheLeader() throws {
        let leaders = try Fixture.decode(PlayerLeaders.self, from: "player_leaders")
        let rows = StatsBoard.playerRows(leaders, category: .efficiency)
        XCTAssertEqual(rows.first?.entry.rosterId, 11453)
        XCTAssertEqual(rows.first?.fraction, 1)
        XCTAssertEqual(rows.map(\.rank), Array(1...rows.count))
        XCTAssertEqual(try XCTUnwrap(rows.dropFirst().first).fraction, 25.8 / 27.4, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(rows.count, StatsBoard.playerLimit)
        XCTAssertTrue(StatsBoard.playerRows(nil, category: .points).isEmpty)
    }
}
