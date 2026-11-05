@testable import BNXT
import XCTest

/// Golden tests on game 11323 (Spirou Basket 65–70 Oostende, 23 Oct 2026): finished, so its data won't change.
final class GameDecodingTests: XCTestCase {
    func testDecodesFinishedGame() throws {
        let game = try Fixture.decode(Envelope<Game>.self, from: "game_11323").data

        XCTAssertEqual(game.id, 11323)
        XCTAssertEqual(game.status, .finished)
        XCTAssertEqual(game.tipOff, GameTime.parse("2026-10-23 20:30:00"))
        XCTAssertEqual(game.period, "Q4")
        XCTAssertEqual(game.arena, "Dôme")
        XCTAssertEqual(game.phaseId, 183)

        // side 1 is home
        XCTAssertEqual(game.home.team.id, 537)
        XCTAssertEqual(game.home.team.shortName, "CHA")
        XCTAssertEqual(game.home.team.country, .belgium)
        XCTAssertEqual(game.home.score, 65)
        XCTAssertEqual(game.home.periodScores, [21, 12, 12, 20])
        XCTAssertEqual(game.away.team.id, 539)
        XCTAssertEqual(game.away.score, 70)
        XCTAssertEqual(game.away.periodScores, [14, 18, 23, 15])
        XCTAssertEqual(game.home.periodScores.reduce(0, +), game.home.score)
        XCTAssertEqual(game.away.periodScores.reduce(0, +), game.away.score)
        XCTAssertEqual(game.winner?.id, 539)
    }

    /// Before tip-off the API sends finalScore 0 and no quarters; that must not read as a 0–0 score.
    func testUpcomingGameHasNoScore() throws {
        let game = try Fixture.decode(Envelope<Game>.self, from: "game_11351_upcoming").data

        XCTAssertEqual(game.status, .scheduled)
        XCTAssertFalse(game.hasStarted)
        XCTAssertNil(game.home.score)
        XCTAssertNil(game.away.score)
        XCTAssertEqual(game.home.periodScores, [])
        XCTAssertNil(game.period)
        XCTAssertNil(game.winner)
    }

    func testDecodesGameSliderWithFIBAIds() throws {
        let games = try Fixture.list(Game.self, from: "game_slider")

        XCTAssertEqual(games.count, 6)
        XCTAssertEqual(games.filter { $0.status == .finished }.count, 3)
        XCTAssertEqual(games.filter { $0.status == .scheduled }.count, 3)
        XCTAssertEqual(games.first { $0.id == 11323 }?.geniusId, 2_873_627)
    }

    func testDecodesTeamGames() throws {
        let games = try Fixture.list(Game.self, from: "team_games_537")

        XCTAssertEqual(games.count, 5)
        XCTAssertTrue(games.allSatisfy { $0.home.team.id == 537 || $0.away.team.id == 537 })
        XCTAssertTrue(games.allSatisfy { $0.status == .finished && $0.home.score != nil })
    }

    /// The live status value is still unknown (§7.4); anything new must decode, not fail.
    func testUnknownStatusIsKeptAsInProgress() {
        XCTAssertEqual(GameStatus(raw: "live"), .inProgress(raw: "live"))
        XCTAssertEqual(GameStatus(raw: "ready"), .scheduled)
        XCTAssertEqual(GameStatus(raw: "FINISHED"), .finished)
    }
}

final class BoxScoreDecodingTests: XCTestCase {
    private func boxScore() throws -> BoxScore {
        try Fixture.decode(Envelope<BoxScore>.self, from: "box_score_11323").data
    }

    func testTeamTotalsMatchTheOfficialBoxScore() throws {
        let box = try boxScore()
        let home = try XCTUnwrap(box.home)
        let away = try XCTUnwrap(box.away)

        XCTAssertEqual(home.team.shortName, "CHA")
        XCTAssertEqual(home.players.count, 12)
        XCTAssertEqual(home.totals.points, 65)
        // `throw_*` are field goals
        XCTAssertEqual(home.totals.fieldGoalsMade, 25)
        XCTAssertEqual(home.totals.fieldGoalsAttempted, 70)
        XCTAssertEqual(home.totals.threePointersMade, 3)
        XCTAssertEqual(home.totals.threePointersAttempted, 27)
        XCTAssertEqual(home.totals.freeThrowsMade, 12)
        XCTAssertEqual(home.totals.freeThrowsAttempted, 13)
        XCTAssertEqual(home.totals.rebounds, 33)
        XCTAssertEqual(home.totals.assists, 12)
        XCTAssertEqual(home.totals.efficiency, 82)

        XCTAssertEqual(away.team.shortName, "OOS")
        XCTAssertEqual(away.totals.points, 70)
        XCTAssertEqual(away.totals.fieldGoalsMade, 23)
        XCTAssertEqual(away.totals.fieldGoalsAttempted, 56)
        XCTAssertEqual(away.totals.threePointersMade, 12)
        XCTAssertEqual(away.totals.rebounds, 36)
        XCTAssertEqual(away.totals.efficiency, 93)
    }

    /// Player lines must add up to the team totals and the game's final score.
    func testPlayerLinesAddUpToTotals() throws {
        let box = try boxScore()
        let game = try Fixture.decode(Envelope<Game>.self, from: "game_11323").data
        for team in box.teams {
            XCTAssertEqual(team.players.map(\.stats.points).reduce(0, +), team.totals.points, team.team.shortName)
            XCTAssertEqual(team.players.map(\.stats.fieldGoalsMade).reduce(0, +), team.totals.fieldGoalsMade, team.team.shortName)
            XCTAssertEqual(team.totals.fieldGoalsMade, team.totals.twoPointersMade + team.totals.threePointersMade)
        }
        XCTAssertEqual(box.home?.totals.points, game.home.score.map(Double.init))
        XCTAssertEqual(box.away?.totals.points, game.away.score.map(Double.init))
    }

    func testDecodesPlayerLine() throws {
        let away = try XCTUnwrap(try boxScore().away)
        let miller = try XCTUnwrap(away.players.first { $0.rosterId == 11281 })

        XCTAssertEqual(miller.player.fullName, "Adam Miller")
        XCTAssertEqual(miller.jersey, "44") // an int in box scores, a string elsewhere
        XCTAssertEqual(miller.position?.abbreviation, "SG")
        XCTAssertEqual(miller.stats.points, 16)
        XCTAssertEqual(miller.stats.minutes, 22)
        XCTAssertEqual(miller.stats.plusMinus, 13)
        XCTAssertEqual(away.players.filter(\.isStarter).count, 5)
    }

    func testEmptyBoxScoreIsDetected() throws {
        XCTAssertTrue(BoxScore(teams: []).isEmpty)
        XCTAssertFalse(try boxScore().isEmpty)
    }
}
