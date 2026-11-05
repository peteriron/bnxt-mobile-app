@testable import BNXT
import XCTest

/// §3.5 / §7.5: ranks, zones and the cut line per view. Fixture: the real table after 5 games (3 Nov 2026):
/// BE order ANT BRU AAL CHA LIM OOS LEU MEC KOR LIE MON, NL order ZWO DBO GRO LEI RCB.
final class StandingsTableTests: XCTestCase {
    /// Fixed here rather than read from config.json, so a config edit can't make these pass by accident.
    static let zones = [
        RemoteConfig.StandingsZone(id: "leader", label: "League leader", color: "#A08CFF", leaguePositionAtMost: 1),
        RemoteConfig.StandingsZone(id: "be-playoffs", label: "BE", color: "#E2FF00", country: .belgium, nationalPositionAtMost: 8),
        RemoteConfig.StandingsZone(id: "nl-playoffs", label: "NL", color: "#FF6A13", country: .netherlands, nationalPositionAtMost: 4)
    ]

    private func table() throws -> StandingsTable {
        StandingsTable(standings: try Fixture.list(Standing.self, from: "standings"), zones: Self.zones)
    }

    private func codes(_ rows: [StandingsTable.Row]) -> [String] { rows.map(\.standing.team.shortName) }

    func testLeagueTableKeepsLeaguePositionsAndZones() throws {
        let rows = try table().rows(for: .league)
        XCTAssertEqual(rows.map(\.rank), Array(1...16))
        let zone = Dictionary(uniqueKeysWithValues: rows.map { ($0.standing.team.shortName, $0.zone?.id) })
        XCTAssertEqual(zone["ANT"], "leader", "first place is the league leader, not just a BE playoff place")
        XCTAssertEqual(zone["BRU"], "be-playoffs")
        XCTAssertEqual(zone["MEC"], "be-playoffs", "8th Belgian club, 13th in the league")
        XCTAssertEqual(zone["KOR"], .some(nil), "9th Belgian club is out")
        XCTAssertEqual(zone["LEI"], "nl-playoffs", "4th Dutch club, 11th in the league")
        XCTAssertEqual(zone["RCB"], .some(nil), "5th Dutch club is out")
    }

    func testCountryTablesReRankAndOnlyShowTheirOwnZone() throws {
        let table = try table()
        let belgium = table.rows(for: .country(.belgium))
        XCTAssertEqual(codes(belgium), ["ANT", "BRU", "AAL", "CHA", "LIM", "OOS", "LEU", "MEC", "KOR", "LIE", "MON"])
        XCTAssertEqual(belgium.map(\.rank), Array(1...11))
        XCTAssertEqual(belgium.first?.zone?.id, "be-playoffs", "the leader zone belongs to the league table")
        XCTAssertEqual(belgium.filter { $0.zone != nil }.count, 8)

        let netherlands = table.rows(for: .country(.netherlands))
        XCTAssertEqual(codes(netherlands), ["ZWO", "DBO", "GRO", "LEI", "RCB"])
        XCTAssertEqual(netherlands.map(\.zone?.id), ["nl-playoffs", "nl-playoffs", "nl-playoffs", "nl-playoffs", nil])
    }

    func testCutLineFollowsTheNationalZone() throws {
        let table = try table()
        XCTAssertNil(table.cutLine(for: .league))
        XCTAssertEqual(table.cutLine(for: .country(.belgium)), 8)
        XCTAssertEqual(table.cutLine(for: .country(.netherlands)), 4)
        XCTAssertNil(StandingsTable(standings: [], zones: []).cutLine(for: .country(.belgium)), "no zone, no line")
    }

    func testNationalRankAndLegend() throws {
        let table = try table()
        XCTAssertEqual(table.nationalRank(of: 537), 4, "Spirou: 4th of the Belgian clubs")
        XCTAssertEqual(table.nationalRank(of: 553), 4, "Leiden: 4th of the Dutch clubs")
        XCTAssertNil(table.nationalRank(of: 1))
        XCTAssertEqual(table.legendZones(for: .league).map(\.id), ["leader", "be-playoffs", "nl-playoffs"])
        XCTAssertEqual(table.legendZones(for: .country(.netherlands)).map(\.id), ["nl-playoffs"])
        XCTAssertEqual(table.gamesPlayed, 5)
    }

    func testCountryComesFromClubsWhenTheAPITeamHasNone() throws {
        let json = #"{"data": [{"team": {"id": 1, "name": "Alpha"}, "position": 1}, {"team": {"id": 2, "name": "Beta"}, "position": 2}]}"#
        let standings = try JSONDecoder().decode(Envelope<LossyArray<Standing>>.self, from: Data(json.utf8)).data.elements
        let table = StandingsTable(standings: standings, zones: Self.zones, countries: [1: .netherlands, 2: .netherlands])
        XCTAssertEqual(table.rows(for: .country(.netherlands)).map(\.rank), [1, 2])
        XCTAssertEqual(table.rows(for: .league).map(\.zone?.id), ["leader", "nl-playoffs"])
    }
}

/// §3.5: "if the season ended today" brackets. BE 1v8, 4v5, 2v7, 3v6; NL 1v4, 2v3.
final class ProjectedBracketTests: XCTestCase {
    func testFirstRoundPairsUseStandardBracketOrder() {
        XCTAssertTrue(ProjectedBracket.firstRoundPairs(seeds: 8).elementsEqual([(1, 8), (4, 5), (2, 7), (3, 6)], by: ==))
        XCTAssertTrue(ProjectedBracket.firstRoundPairs(seeds: 4).elementsEqual([(1, 4), (2, 3)], by: ==))
        XCTAssertTrue(ProjectedBracket.firstRoundPairs(seeds: 2).elementsEqual([(1, 2)], by: ==))
        XCTAssertTrue(ProjectedBracket.firstRoundPairs(seeds: 0).isEmpty)
    }

    private func bracket(_ country: Country, rounds: [(String, Int)]) throws -> ProjectedBracket {
        let table = StandingsTable(standings: try Fixture.list(Standing.self, from: "standings"), zones: StandingsTableTests.zones)
        let settings = PlayoffSettings.Bracket(country: country, label: "x",
                                               rounds: rounds.map { PlayoffSettings.Round(label: $0.0, bestOf: $0.1) })
        return ProjectedBracket(bracket: settings, table: table)
    }

    private func pairs(_ round: ProjectedBracket.Round) -> [String] {
        round.matchups.map { "\($0.higher.standing?.team.shortName ?? "?")-\($0.lower.standing?.team.shortName ?? "?")" }
    }

    func testBelgianBracketSeedsTheTopEight() throws {
        let bracket = try bracket(.belgium, rounds: [("QF", 3), ("SF", 5), ("F", 5)])
        XCTAssertEqual(bracket.rounds.map(\.matchupCount), [4, 2, 1])
        XCTAssertEqual(bracket.rounds.map(\.bestOf), [3, 5, 5])
        XCTAssertEqual(pairs(bracket.rounds[0]), ["ANT-MEC", "CHA-LIM", "BRU-LEU", "AAL-OOS"])
        XCTAssertTrue(bracket.rounds[1].matchups.isEmpty, "later rounds are to be decided")
    }

    func testDutchBracketSeedsTheTopFour() throws {
        let bracket = try bracket(.netherlands, rounds: [("SF", 5), ("F", 7)])
        XCTAssertEqual(bracket.rounds.map(\.matchupCount), [2, 1])
        XCTAssertEqual(pairs(bracket.rounds[0]), ["ZWO-LEI", "DBO-GRO"])
    }

    func testMissingClubsLeaveEmptySeeds() throws {
        // 16 Dutch seeds, only 5 Dutch clubs.
        let bracket = try bracket(.netherlands, rounds: [("R1", 3), ("QF", 3), ("SF", 5), ("F", 7)])
        XCTAssertEqual(bracket.rounds[0].matchups.count, 8)
        XCTAssertNil(bracket.rounds[0].matchups[0].lower.standing, "seed 16 doesn't exist")
        XCTAssertEqual(bracket.rounds[0].matchups[0].higher.standing?.team.shortName, "ZWO")
    }
}
