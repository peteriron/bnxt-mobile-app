@testable import BNXT
import XCTest

/// §3.8: what Search finds. Fixture: Spirou's roster (537).
final class SearchIndexTests: XCTestCase {
    private func players() throws -> [SearchPlayer] {
        SearchIndex.players(from: [537: try Fixture.list(RosterEntry.self, from: "roster_537")])
    }

    private func ids(_ query: String) throws -> [Int] {
        SearchIndex.players(try players(), query: query).map(\.rosterId)
    }

    func testIndexesActiveRosterEntriesWithTheirClub() throws {
        let all = try players()
        XCTAssertEqual(all.count, 13)
        XCTAssertTrue(all.allSatisfy { $0.teamId == 537 })
    }

    func testMatchesFromTheFirstCharacter() throws {
        XCTAssertFalse(try ids("h").isEmpty)
        XCTAssertEqual(try ids("heath"), [11173])
        XCTAssertEqual(try ids("  HEATH "), [11173], "case and surrounding spaces don't matter")
    }

    func testEveryWordMustMatch() throws {
        XCTAssertEqual(try ids("jos hea"), [11173])
        XCTAssertEqual(try ids("heath konieczny"), [])
    }

    func testSurnamePrefixMatchesComeFirst() throws {
        // "ha": Hawkins starts with it; Mohammed, Nigel and others only contain it.
        let found = try ids("ha")
        XCTAssertEqual(found.first, 11189, "Hawkins")
        XCTAssertTrue(found.contains(11265), "Mohammed Tlarhi Amrani contains 'ha'")
    }

    func testIgnoresAccents() {
        let player = SearchPlayer(rosterId: 1, teamId: 1, player: Player(id: 1, firstName: "Jérôme", lastName: "Müller"), position: nil)
        XCTAssertEqual(SearchIndex.players([player], query: "jerome muller").map(\.rosterId), [1])
    }

    func testEmptyQueryFindsNothing() throws {
        XCTAssertTrue(try ids("").isEmpty)
        XCTAssertTrue(try ids("   ").isEmpty)
        XCTAssertTrue(SearchIndex.clubs([], query: "").isEmpty)
    }

    func testResultsAreCapped() {
        let many = (1...50).map { SearchPlayer(rosterId: $0, teamId: 1, player: Player(id: $0, firstName: "A", lastName: "Smith \($0)"), position: nil) }
        XCTAssertEqual(SearchIndex.players(many, query: "smith").count, SearchIndex.playerLimit)
    }

    func testAPlayerListedTwiceAppearsOnce() throws {
        let roster = try Fixture.list(RosterEntry.self, from: "roster_537")
        XCTAssertEqual(SearchIndex.players(from: [537: roster, 539: roster]).count, 13)
    }

    func testClubsByNameCityOrCode() {
        let clubs = [Club(id: 553, shortName: "LEI", displayName: "Zeeuw & Zeeuw Leiden", officialName: "ZZ Leiden", city: "Leiden"),
                     Club(id: 567, shortName: "LIE", displayName: "Liège Basket", officialName: "Liège Basket", city: "Liège")]
        XCTAssertEqual(SearchIndex.clubs(clubs, query: "liege").map(\.id), [567])
        XCTAssertEqual(SearchIndex.clubs(clubs, query: "lei").map(\.id), [553])
        XCTAssertEqual(SearchIndex.clubs(clubs, query: "l").map(\.id), [553, 567])
    }
}
