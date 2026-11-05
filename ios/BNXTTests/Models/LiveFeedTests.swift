@testable import BNXT
import XCTest

/// §7.4: the FIBA LiveStats feed, decoded from a hand-written fixture in its shape (no Genius Sports data in the repo).
final class LiveFeedTests: XCTestCase {
    private func feed() throws -> LiveFeed { try Fixture.decode(LiveFeed.self, from: "livestats_feed") }

    func testClockPeriodAndScoreWithTeamOneAsHome() throws {
        let feed = try feed()
        XCTAssertEqual(feed.clock, "07:42")
        XCTAssertEqual(feed.period, 3)
        XCTAssertFalse(feed.isOvertime)
        XCTAssertEqual(feed.homeScore, 52)
        XCTAssertEqual(feed.awayScore, 49, "a score sent as a string still decodes")
        XCTAssertEqual(feed.statusText, "Q3 07:42")
    }

    func testPlaysNewestFirstAndOneBadPlayDoesNotDropTheRest() throws {
        let plays = try feed().plays
        XCTAssertEqual(plays.map(\.id), [210, 209, 208, 207, 206, 120, 119, 1])
    }

    func testOnlyMadeShotsScore() throws {
        let byId = Dictionary(uniqueKeysWithValues: try feed().plays.map { ($0.id, $0) })
        XCTAssertEqual(byId[210]?.isScore, true, "made 3")
        XCTAssertEqual(byId[208]?.isScore, false, "the feed marks a missed 3 scoring: 1 too")
        XCTAssertEqual(byId[207]?.isScore, true, "made free throw")
        XCTAssertEqual(byId[210]?.line, "A. Home · 3PT made")
        XCTAssertEqual(byId[208]?.line, "B. Away · 3PT missed")
        XCTAssertEqual(byId[210]?.side, 1)
        XCTAssertNil(byId[206]?.side, "tno 0 is a game event")
    }

    func testLastPlaySkipsSubstitutionsAndMarkers() throws {
        XCTAssertEqual(try feed().lastPlay?.id, 210)
        let quiet = LiveFeed(clock: "10:00", period: 3, isOvertime: false, homeScore: 0, awayScore: 0,
                             plays: [LivePlay(id: 2, clock: "10:00", period: 3, side: nil, playerName: nil, kind: .other("period"),
                                              made: true, homeScore: 0, awayScore: 0)])
        XCTAssertNil(quiet.lastPlay)
    }

    func testOvertimeLabelsUnderEitherNumbering() {
        func label(_ period: Int, overtime: Bool) -> String {
            LiveFeed(clock: "", period: period, isOvertime: overtime, homeScore: 0, awayScore: 0, plays: []).periodLabel
        }
        XCTAssertEqual(label(4, overtime: false), "Q4")
        XCTAssertEqual(label(1, overtime: true), "OT")
        XCTAssertEqual(label(5, overtime: true), "OT")
        XCTAssertEqual(label(2, overtime: true), "OT2")
        XCTAssertEqual(label(6, overtime: true), "OT2")
        XCTAssertEqual(label(0, overtime: false), "")
    }

    func testAFeedWithoutBothTeamsIsRejected() {
        XCTAssertThrowsError(try JSONDecoder().decode(LiveFeed.self, from: Data(#"{"clock":"01:00","period":1,"tm":{"1":{"score":3}}}"#.utf8)))
    }

    func testPlayByPlayGroupsByPeriodAndLeavesOutSubstitutionsAndMarkers() throws {
        let periods = PlayByPlay.periods(try feed().plays)
        XCTAssertEqual(periods.map(\.label), ["Q3", "Q2"])
        XCTAssertEqual(periods[0].plays.map(\.id), [210, 208, 207])
        XCTAssertEqual(periods[1].plays.map(\.id), [120, 119])
    }

    func testApplyingTheFeedOverridesScoreAndPeriod() throws {
        let game = try Fixture.decode(Envelope<Game>.self, from: "game_11351_upcoming").data
        let live = game.applying(try feed())
        XCTAssertEqual(live.home.score, 52)
        XCTAssertEqual(live.away.score, 49)
        XCTAssertEqual(live.period, "Q3 07:42")
        XCTAssertEqual(live.home.periodScores, game.home.periodScores, "no period scores in the feed: BNXT's are kept")
        XCTAssertEqual(live.home.team, game.home.team)
    }

    /// §7.16: coaches, officials and players' full names in the feed are never decoded. Fixed lists, so a new
    /// property has to be added here on purpose.
    func testDecodesNoPersonalDetailsBeyondTheScoreboardName() throws {
        let feed = try feed()
        XCTAssertEqual(Mirror(reflecting: feed).children.compactMap(\.label),
                       ["clock", "period", "isOvertime", "homeScore", "awayScore", "homePeriodScores", "awayPeriodScores",
                        "homePlayers", "awayPlayers", "plays"])
        let line = try XCTUnwrap(try Fixture.decode(LiveFeed.self, from: "livestats_11351_live").homePlayers.first)
        XCTAssertEqual(Mirror(reflecting: line).children.compactMap(\.label), ["scoreboardName", "jersey", "isStarter", "stats"])
        XCTAssertEqual(Mirror(reflecting: try XCTUnwrap(feed.plays.first)).children.compactMap(\.label),
                       ["id", "clock", "period", "isOvertime", "side", "playerName", "kind", "made", "homeScore", "awayScore"])
    }
}

final class LiveStatsClientTests: XCTestCase {
    private var router: MockURLProtocol.Router { MockURLProtocol.router }

    override func setUp() { router.reset() }
    override func tearDown() { router.reset() }

    private func client() -> LiveStatsClient {
        LiveStatsClient(baseURL: APIConfiguration.defaultLiveStatsURL, session: MockURLProtocol.session())
    }

    func testFetchesTheGamesDataFileWithoutAKey() async throws {
        try router.stub("/data/2873634/data.json", fixture: "livestats_feed")
        let feed = try await client().feed(geniusId: 2873634)
        XCTAssertEqual(feed.homeScore, 52)
        let request = try XCTUnwrap(router.requests.first)
        XCTAssertEqual(request.url?.host(), "fibalivestats.dcd.shared.geniussports.com")
        XCTAssertNil(request.value(forHTTPHeaderField: "X-Authorization"), "the BNXT key never goes to a third party")
    }

    func testErrorsThrow() async {
        router.stub("/data/1/data.json", status: 404, body: Data())
        do {
            _ = try await client().feed(geniusId: 1)
            XCTFail("expected an error")
        } catch {}
    }
}

/// The real feed of CHA–RCB at half-time, captured live on 5 Nov 2026 (personal details stripped).
final class CapturedLiveFeedTests: XCTestCase {
    private func feed() throws -> LiveFeed { try Fixture.decode(LiveFeed.self, from: "livestats_11351_live") }

    func testDecodesTheRealFeedAtHalfTime() throws {
        let feed = try feed()
        XCTAssertEqual(feed.statusText, "Q2 00:00")
        XCTAssertEqual(feed.homeScore, 31, "team 1 is Spirou, the home side")
        XCTAssertEqual(feed.awayScore, 30)
        XCTAssertEqual(feed.plays.count, 249, "every play decodes")
        XCTAssertEqual(feed.homePeriodScores, [20, 11])
        XCTAssertEqual(feed.awayPeriodScores, [17, 13])
    }

    func testTheNewestMadeShotCarriesTheScoreboardScore() throws {
        let feed = try feed()
        let newest = try XCTUnwrap(feed.plays.first(where: \.isScore))
        XCTAssertEqual(newest.homeScore, feed.homeScore)
        XCTAssertEqual(newest.awayScore, feed.awayScore)
        XCTAssertEqual(feed.plays.filter(\.isScore).count, 29)
    }

    func testScoresNeverGoDownGoingBackInTime() throws {
        let scoring = try feed().plays.filter(\.isScore)
        for (newer, older) in zip(scoring, scoring.dropFirst()) {
            XCTAssertGreaterThanOrEqual(newer.homeScore + newer.awayScore, older.homeScore + older.awayScore,
                                        "plays are newest first (\(newer.id) before \(older.id))")
        }
    }

    func testLastPlayAndPeriods() throws {
        let feed = try feed()
        XCTAssertEqual(feed.lastPlay?.id, 359)
        XCTAssertEqual(feed.lastPlay?.line, "T. Tumba · 3PT missed")
        XCTAssertEqual(PlayByPlay.periods(feed.plays).map(\.label), ["Q2", "Q1"])
    }
}

/// The live box score built from the feed's player lines (BNXT's stays empty while live).
final class LiveBoxScoreTests: XCTestCase {
    private func feed() throws -> LiveFeed { try Fixture.decode(LiveFeed.self, from: "livestats_11351_live") }
    private func game() throws -> Game { try Fixture.decode(Envelope<Game>.self, from: "game_11351_upcoming").data }

    func testPlayerLinesFromTheRealFeed() throws {
        let feed = try feed()
        let heath = try XCTUnwrap(feed.homePlayers.first { $0.scoreboardName == "J. Heath" })
        XCTAssertEqual(heath.jersey, "3")
        XCTAssertTrue(heath.isStarter)
        XCTAssertEqual(heath.stats.minutes, 14 + 35.0 / 60, accuracy: 0.001)
        XCTAssertEqual(heath.stats.points, 5)
        XCTAssertEqual(heath.stats.turnovers, 5)
        // 5 PTS + 1 REB + 2 AST + 2 STL + 0 BLK + 2 fouls drawn − 2 missed FG − 0 missed FT − 5 TO
        XCTAssertEqual(heath.stats.efficiency, 5)
    }

    /// BNXT's VAL formula, from its own box score of game 11323 (Heath: 12 with 5 fouls drawn and 2 blocks received).
    func testEfficiencyIsBNXTsVALFormula() {
        var line = StatLine()
        line.points = 10
        line.rebounds = 4
        line.assists = 3
        line.steals = 1
        line.blocks = 1
        line.fieldGoalsMade = 4
        line.fieldGoalsAttempted = 9
        line.freeThrowsMade = 2
        line.freeThrowsAttempted = 3
        line.turnovers = 2
        line.fouls = 4 // personal fouls don't count
        XCTAssertEqual(LivePlayerLine.efficiency(line, foulsDrawn: 3), 10 + 4 + 3 + 1 + 1 + 3 - 5 - 1 - 2)
    }

    func testMinutes() {
        XCTAssertEqual(LivePlayerLine.minutes("14:35"), 14 + 35.0 / 60, accuracy: 0.001)
        XCTAssertEqual(LivePlayerLine.minutes("0:00"), 0)
        XCTAssertEqual(LivePlayerLine.minutes(nil), 0)
    }

    func testBoxScoreHasThePlayersWhoPlayedAndAddsUpToTheScore() throws {
        let box = LiveBoxScore.make(try feed(), game: try game(), rosters: [:])
        XCTAssertEqual(box.home?.team.id, 537)
        XCTAssertEqual(box.home?.players.count, 9, "players on the bench all game are left out")
        XCTAssertEqual(box.away?.players.count, 8)
        XCTAssertEqual(box.home?.totals.points, 31)
        XCTAssertEqual(box.away?.totals.points, 30)
        XCTAssertFalse(box.isEmpty)
    }

    func testRosterEntriesGiveRowsTheirRosterIdsAndUnknownsGetPlaceholders() throws {
        let rosters = [537: try Fixture.list(RosterEntry.self, from: "roster_537")]
        let box = LiveBoxScore.make(try feed(), game: try game(), rosters: rosters)
        let heath = try XCTUnwrap(box.home?.players.first { $0.player.lastName == "Heath" })
        XCTAssertEqual(heath.rosterId, 11173, "matched by scoreboard name: J. Heath")
        XCTAssertEqual(heath.player.firstName, "Joshua", "the roster's player, not the feed's name")
        XCTAssertTrue(box.home?.players.allSatisfy { $0.rosterId > 0 } == true, "every Spirou player is on the roster")
        XCTAssertTrue(box.away?.players.allSatisfy { $0.rosterId < 0 } == true, "no Rotterdam roster given: placeholders")
        XCTAssertEqual(Set(box.teams.flatMap(\.players).map(\.rosterId)).count, 17, "ids stay unique")
    }
}
