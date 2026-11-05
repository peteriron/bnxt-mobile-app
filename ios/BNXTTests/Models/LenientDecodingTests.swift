@testable import BNXT
import XCTest

/// Regression coverage for sloppy API data: one bad record must never drop a whole list (REQUIREMENTS §4).
final class LenientDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testBadElementIsDroppedNotTheList() throws {
        let json = #"{"data":[{"id":1,"name":"A","short_name":"AAA"},{"id":"oops"},{"id":3,"name":"C","short_name":"CCC"}]}"#
        let teams = try decode(Envelope<LossyArray<Team>>.self, json).data.elements
        XCTAssertEqual(teams.map(\.id), [1, 3])
    }

    func testNumbersMayArriveAsStringsOrFloats() throws {
        let line = try decode(StatLine.self, #"{"points":"12","minute":24.5,"assist":null,"throw_made":"x"}"#)
        XCTAssertEqual(line.points, 12)
        XCTAssertEqual(line.minutes, 24.5)
        XCTAssertEqual(line.assists, 0)
        XCTAssertEqual(line.fieldGoalsMade, 0)
        XCTAssertNil(line.plusMinus)
    }

    func testPercentagesAreNilWithoutAttempts() {
        XCTAssertNil(StatLine.zero.fieldGoalPercentage)
        var line = StatLine()
        line.freeThrowsMade = 3
        line.freeThrowsAttempted = 4
        XCTAssertEqual(line.freeThrowPercentage, 75)
    }

    func testTeamFieldsDegradeGracefully() throws {
        let team = try decode(Team.self, #"{"id":"9","name":"Club","club":{"id":7},"ticket_url":"","team_logo":null,"statistics":[]}"#)
        XCTAssertEqual(team.id, 9)
        XCTAssertEqual(team.shortName, "CLU")
        XCTAssertNil(team.country)
        XCTAssertNil(team.ticketURL)
        XCTAssertNil(team.logo)
        XCTAssertNil(team.statistics)
    }

    func testGameWithoutAwaySideIsRejected() {
        let json = #"{"id":1,"game_time":"2026-11-05 20:30:00","status":"ready","competitors":[{"side":1,"competition_team":{"id":1,"name":"A"}}]}"#
        XCTAssertThrowsError(try decode(Game.self, json))
    }
}

/// REQUIREMENTS §7.16: fields we must never hold don't exist on the types that decode people.
final class PrivacyTests: XCTestCase {
    private let forbidden: Set<String> = ["facebook", "twitter", "instagram", "description", "socialLinks"]

    private func labels(of value: Any) -> Set<String> {
        Set(Mirror(reflecting: value).children.compactMap(\.label))
    }

    func testPeopleTypesHaveNoForbiddenProperties() throws {
        let roster = try XCTUnwrap(try Fixture.list(RosterEntry.self, from: "roster_537").first)
        let line = try XCTUnwrap(try Fixture.decode(Envelope<BoxScore>.self, from: "box_score_11323").data.home?.players.first)
        let leader = try XCTUnwrap(try Fixture.decode(PlayerLeaders.self, from: "player_leaders")[.points].first)

        for value in [roster.player, roster, line, leader] as [Any] {
            let found = labels(of: value).intersection(forbidden)
            XCTAssertTrue(found.isEmpty, "\(type(of: value)) holds \(found)")
        }
        XCTAssertEqual(labels(of: roster.player), ["id", "firstName", "lastName", "nationalityCode", "birthDate", "photo"],
                       "Player gained a property: check it against §7.16 before updating this list")
    }

    func testFixturesContainNoForbiddenKeys() throws {
        let names = ["teams", "roster_537", "player_averages_537", "box_score_11323", "player_game_log_11173", "player_leaders"]
        for name in names {
            let text = String(bytes: try Fixture.data(name), encoding: .utf8) ?? ""
            for key in ["facebook", "twitter", "instagram", "description"] { // fixed list, independent of PrivacyFilter
                XCTAssertFalse(text.contains("\"\(key)\""), "\(name).json contains \(key)")
            }
        }
    }
}
