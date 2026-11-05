@testable import BNXT
import XCTest

/// §3.2: what Home picks to show. Fixtures: the table after 5 games and the game slider of 3 Nov 2026.
final class HomePageTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_750_400) // 4 Nov 2026

    private func table() throws -> StandingsTable {
        StandingsTable(standings: try Fixture.list(Standing.self, from: "standings"), zones: StandingsTableTests.zones)
    }

    private func slider() throws -> [Game] { try Fixture.list(Game.self, from: "game_slider") }

    private func game(_ id: Int, _ time: String, home: Int, away: Int, status: GameStatus, scores: (Int, Int)? = nil) throws -> Game {
        Game(id: id, tipOff: try XCTUnwrap(GameTime.parse(time)), status: status,
             home: GameSide(team: Team(id: home, name: "H", shortName: "H"), score: scores?.0, periodScores: []),
             away: GameSide(team: Team(id: away, name: "A", shortName: "A"), score: scores?.1, periodScores: []))
    }

    // MARK: Games

    func testNextGameAndLastResultForMyClub() throws {
        let games = try slider()
        XCTAssertEqual(HomePage.nextGame(games, clubId: 537)?.id, 11351, "CHA–RCB on 5 Nov")
        XCTAssertEqual(HomePage.lastResult(games, clubId: 537)?.id, 11323, "CHA 65–70 OOS on 23 Oct")
        XCTAssertNil(HomePage.liveGame(games, clubId: 537))
    }

    func testALiveGameIsTheLiveCardNotTheNextGame() throws {
        let games = [try game(1, "2026-11-05 20:30:00", home: 537, away: 551, status: .inProgress(raw: "live"), scores: (40, 38)),
                     try game(2, "2026-11-12 20:30:00", home: 553, away: 537, status: .scheduled)]
        XCTAssertEqual(HomePage.liveGame(games, clubId: 537)?.id, 1)
        XCTAssertEqual(HomePage.nextGame(games, clubId: 537)?.id, 2)
        XCTAssertNil(HomePage.liveGame(games, clubId: 553))
    }

    func testCountdownInLeagueTime() throws {
        let tonight = try XCTUnwrap(GameTime.parse("2026-11-04 20:30:00"))
        let tomorrow = try XCTUnwrap(GameTime.parse("2026-11-05 20:30:00"))
        let inAWeek = try XCTUnwrap(GameTime.parse("2026-11-11 00:30:00"))
        XCTAssertEqual(HomePage.daysUntil(tonight, now: now), 0)
        XCTAssertEqual(HomePage.daysUntil(tomorrow, now: now), 1)
        XCTAssertEqual(HomePage.daysUntil(inAWeek, now: now), 7, "calendar days, not 24-hour periods")
        XCTAssertEqual(HomePage.countdown(to: tonight, now: now), "Today")
        XCTAssertEqual(HomePage.countdown(to: tomorrow, now: now), "Tomorrow")
        XCTAssertEqual(HomePage.countdown(to: inAWeek, now: now), "In 7 days")
    }

    /// The next-game card said "Today" over "Today · 20:30".
    func testNextGameDetailDoesNotRepeatTheCountdown() throws {
        let tonight = try XCTUnwrap(GameTime.parse("2026-11-04 20:30:00"))
        let later = try XCTUnwrap(GameTime.parse("2026-11-12 20:30:00"))
        XCTAssertEqual(HomeScreen.nextGameDetail(tonight, now: now), Format.tipOffTime(tonight))
        XCTAssertEqual(HomeScreen.nextGameDetail(later, now: now),
                       "\(Format.relativeDay(later, now: now)) · \(Format.tipOffTime(later))")
    }

    func testAroundTheLeagueIsTheLastFourDaysWithResultsNewestFirst() throws {
        XCTAssertEqual(HomePage.aroundTheLeague(try slider()).map(\.id), [11327, 11325, 11323])

        let spread = [try game(1, "2026-10-30 20:30:00", home: 1, away: 2, status: .finished, scores: (80, 70)),
                      try game(2, "2026-10-27 00:30:00", home: 3, away: 4, status: .finished, scores: (80, 70)),
                      try game(3, "2026-10-26 23:30:00", home: 5, away: 6, status: .finished, scores: (80, 70)),
                      try game(4, "2026-10-31 20:30:00", home: 7, away: 8, status: .scheduled)]
        XCTAssertEqual(HomePage.aroundTheLeague(spread).map(\.id), [1, 2], "27–30 Oct; the 26th is a fifth day")
        XCTAssertTrue(HomePage.aroundTheLeague([]).isEmpty)
    }

    // MARK: Standing

    func testStandingSummaryInAPlayoffPlace() throws {
        let summary = try XCTUnwrap(HomePage.standing(try table(), clubId: 537))
        XCTAssertEqual(summary.standing.position, 4)
        XCTAssertEqual(summary.country, .belgium)
        XCTAssertEqual(summary.nationalRank, 4, "ANT BRU AAL CHA")
        XCTAssertEqual(summary.playoffStatus, .playoffPlace)
        XCTAssertEqual(summary.snippet.map(\.standing.position), [2, 3, 4, 5, 6], "centred on the club")
    }

    func testLeaderAndOutsideAndSnippetAtTheEdges() throws {
        let table = try table()
        let leader = try XCTUnwrap(HomePage.standing(table, clubId: 541))
        XCTAssertEqual(leader.playoffStatus, .leader)
        XCTAssertEqual(leader.snippet.map(\.standing.position), [1, 2, 3, 4, 5])

        let kortrijk = try XCTUnwrap(HomePage.standing(table, clubId: 565))
        XCTAssertEqual(kortrijk.nationalRank, 9)
        XCTAssertEqual(kortrijk.playoffStatus, .outside)

        let mons = try XCTUnwrap(HomePage.standing(table, clubId: 543))
        XCTAssertEqual(mons.snippet.map(\.standing.position), [12, 13, 14, 15, 16])

        XCTAssertEqual(try XCTUnwrap(HomePage.standing(table, clubId: 549)).playoffStatus, .playoffPlace, "1st Dutch club")
        XCTAssertNil(HomePage.standing(table, clubId: 999))
    }

    func testWithoutZonesThePlayoffStatusIsUnknown() throws {
        let table = StandingsTable(standings: try Fixture.list(Standing.self, from: "standings"), zones: [])
        XCTAssertEqual(try XCTUnwrap(HomePage.standing(table, clubId: 537)).playoffStatus, .unknown)
    }

    func testStandingDetailText() throws {
        let summary = try XCTUnwrap(HomePage.standing(try table(), clubId: 537))
        XCTAssertEqual(HomeStandingCard.detail(summary), "4th of the Belgian clubs · in a playoff place")
    }

    // MARK: Leaders

    func testClubLeadersPerStatAmongPlayersWhoPlayed() throws {
        let leaders = HomePage.clubLeaders(try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537"))
        XCTAssertEqual(leaders.map(\.stat), [.points, .rebounds, .assists, .efficiency])
        let byStat = Dictionary(uniqueKeysWithValues: leaders.map { ($0.stat, $0) })
        XCTAssertEqual(byStat[.points]?.player.player.lastName, "Konieczny Jr")
        XCTAssertEqual(byStat[.points]?.value, 19)
        XCTAssertEqual(byStat[.efficiency]?.player.rosterId, 11181)
        XCTAssertEqual(byStat[.assists]?.player.rosterId, 11173, "Heath, the league's assists leader")
        XCTAssertTrue(HomePage.clubLeaders([]).isEmpty)
    }

    func testLeagueLeadersAreTheVALTopThree() throws {
        let leaders = try Fixture.decode(PlayerLeaders.self, from: "player_leaders")
        XCTAssertEqual(HomePage.leagueLeaders(leaders).map(\.rosterId), [11453, 11237, 11163])
        XCTAssertTrue(HomePage.leagueLeaders(nil).isEmpty)
    }
}
