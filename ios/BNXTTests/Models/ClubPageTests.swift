@testable import BNXT
import XCTest

/// §3.8 club page rules, on Spirou's real fixtures (team 537): five results, LEU away first, BRU away last.
final class ClubPageTests: XCTestCase {
    private let spirou = 537

    private func games() throws -> [Game] {
        try Fixture.list(Game.self, from: "team_games_537") + Fixture.list(Game.self, from: "game_slider")
    }

    func testResultsNewestFirstAndUpcomingSoonestFirst() throws {
        let games = try games()
        XCTAssertEqual(ClubPage.results(games, teamId: spirou).map(\.id).prefix(5), [11339, 11323, 11323, 11303, 11293],
                       "raw lists overlap; the view model de-duplicates")
        XCTAssertEqual(ClubPage.results(try Fixture.list(Game.self, from: "team_games_537"), teamId: spirou).map(\.id),
                       [11339, 11323, 11303, 11293, 11279])
        XCTAssertEqual(ClubPage.upcoming(games, teamId: spirou).map(\.id), [11351])
        XCTAssertTrue(ClubPage.upcoming(games, teamId: 1).isEmpty)
    }

    func testFormIsTheLastFiveOldestFirst() throws {
        let results = ClubPage.results(try Fixture.list(Game.self, from: "team_games_537"), teamId: spirou)
        // 11279 L at LEU, 11293 W v MON, 11303 W at GRO, 11323 L v OOS, 11339 W at BRU
        XCTAssertEqual(ClubPage.form(results: results, teamId: spirou), [false, true, true, false, true])
        XCTAssertEqual(ClubPage.form(results: results, teamId: spirou, count: 2), [false, true])
    }

    func testArenaComesFromTheLatestHomeGame() throws {
        XCTAssertEqual(ClubPage.arena(games: try games(), teamId: spirou), "Dôme", "an away arena or a home game without one must not win")
        XCTAssertNil(ClubPage.arena(games: [], teamId: spirou))
    }

    func testRosterTakesJerseysFromTheBoxScoreAndSortsByNumber() throws {
        let roster = try Fixture.list(RosterEntry.self, from: "roster_537")
        XCTAssertTrue(roster.allSatisfy { ($0.jersey ?? "").isEmpty }, "precondition: Spirou's roster has no numbers")
        let box = try Fixture.decode(Envelope<BoxScore>.self, from: "box_score_11323").data
        let jerseys = ClubPage.jerseys(from: [box], teamId: spirou)
        XCTAssertEqual(jerseys[212], "3", "Heath")
        XCTAssertNil(jerseys[42], "Oostende's players aren't Spirou's")

        let rows = ClubPage.roster(roster, jerseys: jerseys, averages: try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537"))
        XCTAssertEqual(rows.count, 13)
        let numbers = rows.compactMap { $0.jersey.flatMap(Int.init) }
        XCTAssertEqual(numbers, numbers.sorted(), "numbered players in jersey order")
        XCTAssertEqual(rows.first { $0.entry.player.lastName == "Heath" }?.pointsPerGame, 7.8)
        if let firstUnnumbered = rows.firstIndex(where: { $0.jersey == nil }) {
            XCTAssertTrue(rows[firstUnnumbered...].allSatisfy { $0.jersey == nil }, "players without a number come last")
        }
    }

    func testPlayerStatsSortByTheChosenColumn() throws {
        let averages = try Fixture.list(PlayerSeasonAverages.self, from: "player_averages_537")
        let byPoints = ClubPage.playerStats(averages, sortedBy: .points)
        XCTAssertEqual(byPoints.prefix(3).map(\.player.lastName), ["Konieczny Jr", "Andre", "Polet"])
        XCTAssertTrue(byPoints.allSatisfy { $0.gamesPlayed > 0 })
        let byTurnovers = ClubPage.playerStats(averages, sortedBy: .turnovers).map(\.perGame.turnovers)
        XCTAssertEqual(byTurnovers, byTurnovers.sorted(by: >))
    }

    func testNationalityFlagsAndNames() {
        XCTAssertEqual(Nationality.flag(ioc: "USA"), "🇺🇸")
        XCTAssertEqual(Nationality.flag(ioc: "NED"), "🇳🇱", "IOC NED is ISO NL")
        XCTAssertEqual(Nationality.flag(ioc: "SUI"), "🇨🇭")
        XCTAssertNil(Nationality.flag(ioc: "XYZ"))
        XCTAssertEqual(Nationality.name(ioc: "ANG", locale: Locale(identifier: "en")), "Angola")
        XCTAssertEqual(Nationality.name(ioc: "XYZ", locale: Locale(identifier: "en")), "XYZ")
    }

    func testOrdinals() {
        let english = Locale(identifier: "en")
        XCTAssertEqual([1, 2, 3, 4, 11, 12, 13, 21].map { Format.ordinal($0, locale: english) },
                       ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st"])
    }

    @MainActor
    func testClubSearchMatchesNamesCitiesAndCodes() {
        let clubs = [
            Club(id: 1, shortName: "LIE", displayName: "Liège", officialName: "RSW Liège Basket", city: "Liège"),
            Club(id: 2, shortName: "ZWO", displayName: "Landstede Hammers", officialName: "Landstede Hammers", city: "Zwolle")
        ]
        XCTAssertEqual(ClubsScreen.filter(clubs, query: "").count, 2)
        XCTAssertEqual(ClubsScreen.filter(clubs, query: "liege").map(\.id), [1], "diacritics don't matter")
        XCTAssertEqual(ClubsScreen.filter(clubs, query: "zwolle").map(\.id), [2], "by city")
        XCTAssertEqual(ClubsScreen.filter(clubs, query: " zwo ").map(\.id), [2], "by code, trimmed")
        XCTAssertTrue(ClubsScreen.filter(clubs, query: "ajax").isEmpty)
    }

    @MainActor
    func testGridRows() {
        let clubs = (1...5).map { Club(id: $0, shortName: "C\($0)", displayName: "Club \($0)", officialName: "Club \($0)") }
        XCTAssertEqual(ClubsScreen.rows(clubs, columns: 3).map { $0.map(\.id) }, [[1, 2, 3], [4, 5]])
        XCTAssertEqual(ClubsScreen.rows(clubs, columns: 2).map(\.count), [2, 2, 1])
        XCTAssertTrue(ClubsScreen.rows([], columns: 3).isEmpty)
    }
}
