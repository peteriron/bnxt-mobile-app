@testable import BNXT
import XCTest

/// §3.8 player page rules on Joshua Heath's real game log (roster 11173, Spirou): 4, 8, 5, 13, 9 points in
/// 11279 @LEU (L 65-69), 11293 v MON, 11303 @GRO, 11323 v OOS (L 65-70), 11339 @BRU (W 81-66).
final class PlayerPageTests: XCTestCase {
    private func lines() throws -> [PlayerGameLine] {
        try Fixture.list(PlayerGameLine.self, from: "player_game_log_11173")
    }

    func testSeasonAveragesComeFromTheGameLog() throws {
        let season = try XCTUnwrap(PlayerPage.season(try lines()))
        XCTAssertEqual(season.games, 5)
        XCTAssertEqual(season.totals.points, 39)
        XCTAssertEqual(season.perGame.points, 7.8, accuracy: 0.001, "matches the league's own 7.8 in player_averages_537")
        XCTAssertNil(PlayerPage.season([]), "no games: bio only")
    }

    func testShootingPercentagesUseTotalsNotAveragedPercentages() throws {
        let season = try XCTUnwrap(PlayerPage.season(try lines()))
        let expected = 100 * season.totals.fieldGoalsMade / season.totals.fieldGoalsAttempted
        XCTAssertEqual(try XCTUnwrap(season.totals.fieldGoalPercentage), expected, accuracy: 0.001)
        XCTAssertEqual(season.perGame.fieldGoalsAttempted * 5, season.totals.fieldGoalsAttempted, accuracy: 0.001)
    }

    func testGameLogIsNewestFirstFromThePlayersSide() throws {
        let log = PlayerPage.log(try lines())
        XCTAssertEqual(log.map(\.id), [11339, 11323, 11303, 11293, 11279])
        let bru = try XCTUnwrap(log.first)
        XCTAssertEqual(bru.opponent.shortName, "BRU")
        XCTAssertFalse(bru.isHome)
        XCTAssertEqual(bru.won, true)
        XCTAssertEqual(bru.teamScore, 81)
        XCTAssertEqual(bru.opponentScore, 66)
        let oostende = log[1]
        XCTAssertTrue(oostende.isHome)
        XCTAssertEqual(oostende.won, false)
        XCTAssertEqual([oostende.teamScore, oostende.opponentScore], [65, 70])
    }

    func testPointsChartIsOldestFirstWithOpponentLabels() throws {
        let chart = PlayerPage.pointsChart(try lines())
        XCTAssertEqual(chart.values, [4, 8, 5, 13, 9])
        XCTAssertEqual(chart.labels, ["LEU", "MON", "GRO", "OOS", "BRU"])
    }

    func testJerseyPrefersTheRosterThenTheLatestGame() throws {
        let entry = try Fixture.decode(Envelope<RosterEntry>.self, from: "roster_entry_11173").data
        XCTAssertEqual(entry.jersey, nil, "precondition: the roster sends no number for Heath")
        XCTAssertEqual(PlayerPage.jersey(entry: entry, lines: try lines()), "3")
        XCTAssertNil(PlayerPage.jersey(entry: entry, lines: []))
    }

    func testRankBadgesOnlyForTheTopTen() throws {
        let leaders = try Fixture.decode(PlayerLeaders.self, from: "player_leaders")
        XCTAssertEqual(PlayerPage.leagueRank(leaders, rosterId: 11173, category: .assists), 1, "Heath leads the league in assists")
        XCTAssertNil(PlayerPage.leagueRank(leaders, rosterId: 11173, category: .points))
        XCTAssertNil(PlayerPage.leagueRank(nil, rosterId: 11173, category: .assists))

        let entries = (1...11).map { rank in
            #"{"player": {"id": \#(rank), "last_name": "P\#(rank)"}, "team": {"id": 1, "name": "T"}, "roster_id": \#(rank), "value": \#(20 - rank)}"#
        }
        let json = #"{"points": [\#(entries.joined(separator: ","))]}"#
        let eleven = try JSONDecoder().decode(PlayerLeaders.self, from: Data(json.utf8))
        XCTAssertEqual(PlayerPage.leagueRank(eleven, rosterId: 10, category: .points), 10)
        XCTAssertNil(PlayerPage.leagueRank(eleven, rosterId: 11, category: .points), "11th gets no badge")
    }
}
