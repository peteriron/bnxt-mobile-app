@testable import BNXT
import XCTest

final class TeamDecodingTests: XCTestCase {
    func testDecodesAllClubs() throws {
        let teams = try Fixture.list(Team.self, from: "teams")

        XCTAssertEqual(teams.count, 16)
        XCTAssertEqual(teams.filter { $0.country == .belgium }.count, 11)
        XCTAssertEqual(teams.filter { $0.country == .netherlands }.count, 5)
        XCTAssertTrue(teams.allSatisfy { $0.logo != nil })
        // `competition-team/all` sends statistics as an empty list, which must not fail decoding
        XCTAssertTrue(teams.allSatisfy { $0.statistics == nil })
    }

    func testTeamFindIncludesSeasonAverages() throws {
        let team = try Fixture.decode(Envelope<Team>.self, from: "team_537").data

        XCTAssertEqual(team.name, "Val-Dieu Spirou Basket")
        XCTAssertEqual(team.shortName, "CHA")
        XCTAssertNotNil(team.ticketURL)
        XCTAssertEqual(team.statistics, TeamStatistics(pointsFor: 79.8, pointsAgainst: 65.6, fieldGoalPercentage: 44.48))
    }
}

final class StandingsDecodingTests: XCTestCase {
    func testDecodesStandings() throws {
        let rows = try Fixture.list(Standing.self, from: "standings")

        XCTAssertEqual(rows.count, 16)
        XCTAssertEqual(rows.map(\.position), Array(1...16))
        let leader = rows[0]
        XCTAssertEqual(leader.team.shortName, "ANT")
        XCTAssertEqual(leader.wins, 5)
        XCTAssertEqual(leader.losses, 0)
        XCTAssertEqual(leader.pointsFor, 535)
        XCTAssertEqual(leader.pointsAgainst, 410)
        XCTAssertEqual(leader.pointDifference, 125)
        XCTAssertEqual(leader.home, WinLoss(wins: 3, losses: 0))
        XCTAssertEqual(leader.away, WinLoss(wins: 2, losses: 0))
        XCTAssertEqual(leader.lastFive, WinLoss(wins: 5, losses: 0))
        XCTAssertEqual(leader.streak?.isWinning, true)
        XCTAssertEqual(leader.streak?.count, 5)
        XCTAssertEqual(rows.last?.team.shortName, "MON")
        XCTAssertTrue(rows.allSatisfy { $0.wins + $0.losses == $0.played })
    }
}

final class PlayerDecodingTests: XCTestCase {
    func testDecodesRoster() throws {
        let roster = try Fixture.list(RosterEntry.self, from: "roster_537")

        XCTAssertEqual(roster.count, 13)
        let heath = try XCTUnwrap(roster.first { $0.id == 11173 })
        XCTAssertEqual(heath.player.fullName, "Joshua Heath")
        XCTAssertEqual(heath.player.shortName, "J. Heath")
        XCTAssertEqual(heath.teamId, 537)
        XCTAssertEqual(heath.heightCm, 188)
        XCTAssertEqual(heath.position?.positions, [.pointGuard])
        XCTAssertEqual(heath.player.nationalityCode, "USA")
        XCTAssertEqual(heath.player.birthDate, BirthDate(string: "1994-12-28"))
        // rosters send "" for the jersey here; box scores carry the number
        XCTAssertNil(heath.jersey)
    }

    /// Missing heights and photos are real (Tlarhi Amrani, Mbessang) and must not drop the player.
    func testKeepsPlayersWithMissingFields() throws {
        let roster = try Fixture.list(RosterEntry.self, from: "roster_537")

        XCTAssertEqual(roster.filter { $0.heightCm == nil }.count, 1)
        XCTAssertEqual(roster.filter { $0.player.photo == nil }.count, 1)
        XCTAssertEqual(roster.filter { $0.player.birthDate == nil }.count, 2)
    }

    func testAgeIsComputedInLeagueTime() throws {
        let heath = Player(id: 1, firstName: "Joshua", lastName: "Heath", birthDate: BirthDate(string: "1994-12-28"))
        let dayBefore = try XCTUnwrap(GameTime.parse("2026-12-27 23:59:00"))
        let birthday = try XCTUnwrap(GameTime.parse("2026-12-28 00:00:00"))

        XCTAssertEqual(heath.age(on: dayBefore), 31)
        XCTAssertEqual(heath.age(on: birthday), 32)
        XCTAssertNil(Player(id: 2, firstName: "", lastName: "X").age(on: birthday))
    }

    func testParsesPositionCombinations() {
        XCTAssertEqual(PlayingPosition(apiName: "small_forward-power_forward")?.abbreviation, "SF/PF")
        XCTAssertEqual(PlayingPosition(apiName: "center")?.abbreviation, "C")
        XCTAssertNil(PlayingPosition(apiName: "coach"))
        XCTAssertNil(BirthDate(string: "1994-13-01"))
    }

    func testDecodesSeasonAverages() throws {
        let averages = try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537")

        XCTAssertEqual(averages.count, 12)
        let heath = try XCTUnwrap(averages.first { $0.rosterId == 11173 })
        XCTAssertEqual(heath.gamesPlayed, 5)
        XCTAssertEqual(heath.gamesStarted, 5)
        XCTAssertEqual(heath.perGame.points, 7.8)
        XCTAssertEqual(heath.perGame.minutes, 28)
    }

    func testDecodesGameLog() throws {
        let log = try Fixture.list(PlayerGameLine.self, from: "player_game_log_11173")

        XCTAssertEqual(log.count, 5)
        let line = try XCTUnwrap(log.first { $0.game.id == 11323 })
        XCTAssertEqual(line.stats.points, 13)
        XCTAssertEqual(line.jersey, "3")
        XCTAssertEqual(line.teamId, 537)
        XCTAssertNil(line.stats.plusMinus) // game logs don't send plus-minus
    }

    /// An unknown roster id answers `{"data":[],"error":"Roster player not found."}` with HTTP 200.
    func testUnknownRosterIdGivesAnEmptyGameLog() throws {
        XCTAssertEqual(try Fixture.list(PlayerGameLine.self, from: "player_game_log_unknown"), [])
    }
}

final class LeadersDecodingTests: XCTestCase {
    func testDecodesEveryCategory() throws {
        let leaders = try Fixture.decode(PlayerLeaders.self, from: "player_leaders")

        XCTAssertEqual(Set(leaders.categories.keys), Set(LeaderCategory.allCases))
        let top = try XCTUnwrap(leaders[.points].first)
        XCTAssertEqual(top.player.lastName, "Thomas")
        XCTAssertEqual(top.team.shortName, "AAL")
        XCTAssertEqual(top.value, 24.2)
        XCTAssertEqual(leaders.rank(of: 11139, in: .points), 1)
        XCTAssertNil(leaders.rank(of: -1, in: .points))
        XCTAssertTrue(LeaderCategory.freeThrowPercentage.isPercentage)
        XCTAssertFalse(LeaderCategory.points.isPercentage)
    }
}
