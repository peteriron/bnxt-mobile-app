@testable import BNXT
import XCTest

/// §3.3 Games list rules. Slider fixture: finished 11323 (23 Oct 20:30, CHA–OOS), 11325 (24 Oct 20:00),
/// 11327 (24 Oct 20:30); scheduled 11351 (5 Nov, CHA–RCB), 11353 (6 Nov), 11355 (7 Nov).
final class GamesListTests: XCTestCase {
    private func slider() throws -> [Game] { try Fixture.list(Game.self, from: "game_slider") }

    static func liveGame(id: Int = 1, home: Int = 537, away: Int = 551) -> Game {
        Game(id: id, tipOff: Date(timeIntervalSince1970: 1_793_750_400), status: .inProgress(raw: "live"),
             home: GameSide(team: Team(id: home, name: "Home", shortName: "HOM"), score: 40, periodScores: [20, 20]),
             away: GameSide(team: Team(id: away, name: "Away", shortName: "AWY"), score: 38, periodScores: [19, 19]),
             period: "Q2")
    }

    func testUpcomingIsSoonestFirstGroupedByDay() throws {
        let sections = GamesList.sections(try slider(), mode: .upcoming, clubId: nil)
        XCTAssertTrue(sections.live.isEmpty)
        XCTAssertEqual(sections.days.map { $0.games.map(\.id) }, [[11351], [11353], [11355]])
    }

    func testResultsAreNewestFirstGroupedByDay() throws {
        let sections = GamesList.sections(try slider(), mode: .results, clubId: nil)
        XCTAssertEqual(sections.days.map { $0.games.map(\.id) }, [[11327, 11325], [11323]],
                       "24 Oct (20:30 before 20:00), then 23 Oct")
    }

    func testMyClubFilter() throws {
        XCTAssertEqual(GamesList.sections(try slider(), mode: .upcoming, clubId: 537).days.flatMap(\.games).map(\.id), [11351])
        XCTAssertEqual(GamesList.sections(try slider(), mode: .results, clubId: 537).days.flatMap(\.games).map(\.id), [11323])
        XCTAssertTrue(GamesList.sections(try slider(), mode: .results, clubId: 1).days.isEmpty)
    }

    func testLiveGamesArePinnedInUpcomingOnly() throws {
        let games = try slider() + [Self.liveGame()]
        let upcoming = GamesList.sections(games, mode: .upcoming, clubId: nil)
        XCTAssertEqual(upcoming.live.map(\.id), [1])
        XCTAssertFalse(upcoming.days.flatMap(\.games).contains { $0.id == 1 }, "not repeated under its day")
        XCTAssertFalse(GamesList.sections(games, mode: .results, clubId: nil).days.flatMap(\.games).contains { $0.id == 1 })
    }

    func testDuplicateGamesAppearOnce() throws {
        let games = try slider() + slider()
        XCTAssertEqual(GamesList.sections(games, mode: .upcoming, clubId: nil).days.flatMap(\.games).count, 3)
    }

    func testDayHeaders() throws {
        let english = Locale(identifier: "en_GB")
        let now = try XCTUnwrap(GameTime.parse("2026-11-05 10:00:00"))
        let tonight = try XCTUnwrap(GameTime.parse("2026-11-05 20:30:00"))
        let tomorrow = try XCTUnwrap(GameTime.parse("2026-11-06 20:30:00"))
        let saturday = try XCTUnwrap(GameTime.parse("2026-11-07 20:30:00"))
        let yesterday = try XCTUnwrap(GameTime.parse("2026-11-04 23:30:00"))
        XCTAssertEqual(Format.dayHeader(tonight, now: now, locale: english), "Today")
        XCTAssertEqual(Format.dayHeader(tomorrow, now: now, locale: english), "Tomorrow")
        XCTAssertEqual(Format.dayHeader(yesterday, now: now, locale: english), "Yesterday")
        XCTAssertEqual(Format.dayHeader(saturday, now: now, locale: english), "Saturday 7 November")
    }
}

/// §3.4 game detail rules on the real finished game 11323 (CHA 65–70 OOS) and the upcoming 11351.
final class GameDetailTests: XCTestCase {
    private func finished() throws -> Game { try Fixture.decode(Envelope<Game>.self, from: "game_11323").data }
    private func upcoming() throws -> Game { try Fixture.decode(Envelope<Game>.self, from: "game_11351_upcoming").data }
    private func box() throws -> BoxScore { try Fixture.decode(Envelope<BoxScore>.self, from: "box_score_11323").data }

    func testTabsDependOnTheGamesState() throws {
        XCTAssertEqual(GameDetail.tabs(for: try finished()), [.summary, .boxScore, .info])
        XCTAssertEqual(GameDetail.tabs(for: try upcoming()), [.preview, .info])
        XCTAssertEqual(GameDetail.tabs(for: GamesListTests.liveGame()), [.boxScore, .summary, .info])
    }

    func testQuarterColumnsAddOvertimeOnlyWhenPlayed() throws {
        XCTAssertEqual(GameDetail.periodTitles(try finished()), ["Q1", "Q2", "Q3", "Q4"])
        let side = GameSide(team: Team(id: 1, name: "A", shortName: "A"), score: 100, periodScores: [20, 20, 20, 20, 10, 10])
        let overtime = Game(id: 2, tipOff: .now, status: .finished, home: side, away: side)
        XCTAssertEqual(GameDetail.periodTitles(overtime), ["Q1", "Q2", "Q3", "Q4", "OT", "OT2"])
    }

    func testComparisonOnTheRealBoxScore() throws {
        let box = try box()
        let home = try XCTUnwrap(box.home), away = try XCTUnwrap(box.away)
        XCTAssertEqual(home.team.id, 537)
        let rows = Dictionary(uniqueKeysWithValues: GameDetail.comparison(home: home.totals, away: away.totals).map { ($0.id, $0) })
        XCTAssertEqual(rows.keys.sorted(), ["3p", "ast", "blk", "fg", "ft", "reb", "stl", "tov"])
        let fieldGoals = try XCTUnwrap(rows["fg"])
        XCTAssertEqual(fieldGoals.homeDetail, Format.madeAttempted(home.totals.fieldGoalsMade, home.totals.fieldGoalsAttempted))
        XCTAssertTrue(fieldGoals.isPercentage)
        XCTAssertTrue(try XCTUnwrap(rows["tov"]).lowerWins)
    }

    func testComparisonWinnerRules() {
        func row(_ home: Double, _ away: Double, lowerWins: Bool) -> GameDetail.ComparisonRow {
            GameDetail.ComparisonRow(id: "x", title: "x", home: home, away: away, homeDetail: nil, awayDetail: nil,
                                     isPercentage: false, lowerWins: lowerWins)
        }
        XCTAssertEqual(row(10, 8, lowerWins: false).better, .home)
        XCTAssertEqual(row(10, 8, lowerWins: true).better, .away, "fewer turnovers win")
        XCTAssertEqual(row(9, 9, lowerWins: false).better, .neither)
        XCTAssertEqual(row(0, 0, lowerWins: false).homeShare, 0.5)
        XCTAssertEqual(row(30, 10, lowerWins: false).homeShare, 0.75)
    }

    func testTopPerformerAndLeaders() throws {
        let home = try XCTUnwrap(try box().home)
        let top = try XCTUnwrap(GameDetail.topPerformer(home))
        XCTAssertEqual(top.stats.efficiency, home.players.map(\.stats.efficiency).max())
        let scorer = try XCTUnwrap(GameDetail.leader(home, \.points))
        XCTAssertEqual(scorer.stats.points, home.players.map(\.stats.points).max())
        XCTAssertNil(GameDetail.topPerformer(nil))
    }

    func testTeamFormFromPlayerAverages() throws {
        let players = try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537")
        let stats = try XCTUnwrap(try Fixture.decode(Envelope<Team>.self, from: "team_537").data.statistics)
        let form = GameDetail.teamForm(statistics: stats, players: players, gamesPlayed: 5)
        XCTAssertEqual(form.pointsFor, 79.8)
        let rebounds = players.reduce(0) { $0 + $1.perGame.rebounds * Double($1.gamesPlayed) } / 5
        XCTAssertEqual(try XCTUnwrap(form.rebounds), rebounds, accuracy: 0.001)
        XCTAssertNotNil(form.threePointPercentage)
        XCTAssertNil(GameDetail.teamForm(statistics: nil, players: players, gamesPlayed: 0).rebounds, "no games: no per-game numbers")
    }

    func testPlayerToWatchIsTheHighestValuation() throws {
        let players = try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537")
        let watch = try XCTUnwrap(GameDetail.playerToWatch(players))
        XCTAssertEqual(watch.perGame.efficiency, players.filter { $0.gamesPlayed > 0 }.map(\.perGame.efficiency).max())
    }

    func testEarlierMeetingsAreTheSamePairingFinished() throws {
        let finished = try finished()
        let games = try Fixture.list(Game.self, from: "team_games_537")
        // CHA–OOS in 11323; a later CHA–OOS game would list it.
        let rematch = Game(id: 99, tipOff: .now, status: .scheduled, home: finished.away, away: finished.home)
        XCTAssertEqual(GameDetail.earlierMeetings(of: rematch, in: games + games).map(\.id), [11323], "reverse fixture, de-duplicated")
        XCTAssertTrue(GameDetail.earlierMeetings(of: finished, in: games).isEmpty, "a game isn't its own earlier meeting")
    }

    func testInfoLinksAndTimeZone() throws {
        XCTAssertEqual(GameDetail.reportURL(gameId: 11323)?.absoluteString, "https://bnxtleague.com/en/game-report/11323")
        XCTAssertEqual(GameDetail.zoneAbbreviation(at: try XCTUnwrap(GameTime.parse("2026-11-05 20:30:00"))), "CET")
        XCTAssertEqual(GameDetail.zoneAbbreviation(at: try XCTUnwrap(GameTime.parse("2027-05-14 20:30:00"))), "CEST")
    }

    func testCalendarEvent() throws {
        let game = try upcoming()
        let home = Club(id: 537, shortName: "CHA", displayName: "Spirou Basket", officialName: "x", city: "Charleroi")
        let away = Club(id: 551, shortName: "RCB", displayName: "Rotterdam", officialName: "x")
        let draft = CalendarEventDraft(game: game, home: home, away: away)
        XCTAssertEqual(draft.title, "Spirou Basket – Rotterdam")
        XCTAssertEqual(draft.start, game.tipOff)
        XCTAssertEqual(draft.end.timeIntervalSince(draft.start), 7200)
        XCTAssertEqual(draft.url, GameDetail.reportURL(gameId: game.id))
        XCTAssertTrue(draft.location?.hasSuffix("Charleroi") ?? false)
    }
}
