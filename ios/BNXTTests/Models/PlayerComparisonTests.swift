@testable import BNXT
import XCTest

/// §3.7: which value wins, the default slots, swapping and the picker's search.
final class PlayerComparisonTests: XCTestCase {
    /// A candidate decoded the way the API sends player averages.
    private func candidate(_ rosterId: Int, team: Int, first: String = "First", last: String, games: Int, val: Double,
                           extra: [String: Any] = [:]) throws -> CompareCandidate {
        var json: [String: Any] = ["roster_id": rosterId, "played_games": games, "value": val,
                                   "player": ["id": rosterId, "first_name": first, "last_name": last]]
        json.merge(extra) { _, new in new }
        let averages = try JSONDecoder().decode(PlayerSeasonAverages.self, from: JSONSerialization.data(withJSONObject: json))
        return CompareCandidate(averages: averages, teamId: team)
    }

    // MARK: Better value

    func testHigherWinsExceptTurnovers() {
        XCTAssertEqual(PlayerComparison.better(.points, first: 12, second: 10), .first)
        XCTAssertEqual(PlayerComparison.better(.points, first: 10, second: 12), .second)
        XCTAssertEqual(PlayerComparison.better(.turnovers, first: 1.2, second: 2.8), .first, "fewer turnovers is better")
    }

    func testEqualAsShownHighlightsNeither() {
        XCTAssertNil(PlayerComparison.better(.points, first: 7.81, second: 7.79), "both show 7.8")
        XCTAssertNil(PlayerComparison.better(.fieldGoalPercentage, first: 45.2, second: 44.8), "both show 45%")
        XCTAssertNil(PlayerComparison.better(.gamesPlayed, first: 5, second: 5))
        XCTAssertEqual(PlayerComparison.better(.points, first: 7.86, second: 7.8), .first, "7.9 vs 7.8")
    }

    func testMissingValueHighlightsNeither() {
        XCTAssertNil(PlayerComparison.better(.threePointPercentage, first: nil, second: 30))
    }

    func testPercentagesNeedAttempts() throws {
        let shooter = try candidate(1, team: 1, last: "A", games: 1, val: 1,
                                    extra: ["three_point_made": 1, "three_point_all": 4, "free_throw_all": 0])
        XCTAssertEqual(CompareStat.threePointPercentage.value(shooter), 25)
        XCTAssertNil(CompareStat.freeThrowPercentage.value(shooter))
        XCTAssertEqual(CompareStat.freeThrowPercentage.formatted(nil), "–")
        XCTAssertEqual(CompareStat.gamesPlayed.value(shooter), 1)
    }

    func testTwelveStatsInSpecOrder() {
        XCTAssertEqual(CompareStat.allCases, [.points, .rebounds, .assists, .steals, .blocks, .turnovers, .fieldGoalPercentage,
                                              .threePointPercentage, .freeThrowPercentage, .efficiency, .minutes, .gamesPlayed])
    }

    // MARK: Defaults

    private func league() throws -> [CompareCandidate] {
        [try candidate(1, team: 10, last: "Star", games: 10, val: 25),
         try candidate(2, team: 10, last: "Second", games: 9, val: 20),
         try candidate(3, team: 20, last: "Mine", games: 10, val: 15),
         try candidate(4, team: 20, last: "OneGame", games: 1, val: 40),
         try candidate(5, team: 20, last: "Bench", games: 0, val: 0)]
    }

    func testDefaultsAreMyClubsTopPlayerAndTheLeagueLeader() throws {
        let slots = PlayerComparison.defaults(try league(), favoriteClubId: 20, preset: nil)
        XCTAssertEqual(slots.first, 3, "my club's best qualified VAL, not the one-game 40")
        XCTAssertEqual(slots.second, 1, "league VAL leader among qualified players")
    }

    func testBIsTheNextLeaderWhenTheLeaderIsA() throws {
        let slots = PlayerComparison.defaults(try league(), favoriteClubId: 10, preset: nil)
        XCTAssertEqual(slots.first, 1)
        XCTAssertEqual(slots.second, 2)
    }

    func testPresetFillsA() throws {
        XCTAssertEqual(PlayerComparison.defaults(try league(), favoriteClubId: 20, preset: 2).first, 2)
        XCTAssertEqual(PlayerComparison.defaults(try league(), favoriteClubId: 20, preset: 999).first, 3, "unknown preset falls back")
    }

    func testWithoutAFavouriteAIsTheLeader() throws {
        let slots = PlayerComparison.defaults(try league(), favoriteClubId: nil, preset: nil)
        XCTAssertEqual(slots.first, 1)
        XCTAssertEqual(slots.second, 2)
    }

    func testQualifiedNeedsHalfTheMostGames() throws {
        XCTAssertEqual(PlayerComparison.qualified(try league()).map(\.id), [1, 2, 3])
    }

    func testNoCandidatesNoDefaults() {
        let slots = PlayerComparison.defaults([], favoriteClubId: 20, preset: 3)
        XCTAssertNil(slots.first)
        XCTAssertNil(slots.second)
    }

    // MARK: Choosing

    func testChoosingTheOtherSlotsPlayerSwaps() {
        XCTAssertTrue(PlayerComparison.choose(2, for: .first, current: (1, 2)) == (2, 1))
        XCTAssertTrue(PlayerComparison.choose(1, for: .second, current: (1, 2)) == (2, 1))
        XCTAssertTrue(PlayerComparison.choose(3, for: .first, current: (1, 2)) == (3, 2))
        XCTAssertTrue(PlayerComparison.choose(3, for: .second, current: (1, 2)) == (1, 3))
    }

    // MARK: Search

    func testSearchByPlayerOrClubBestFirstWithoutBenchPlayers() throws {
        let clubs: [Int: [String]] = [10: ["Spirou Basket", "CHA"], 20: ["Heroes Den Bosch", "DBO"]]
        let all = PlayerComparison.search(try league(), query: "", clubNames: { clubs[$0] ?? [] })
        XCTAssertEqual(all.map(\.id), [4, 1, 2, 3], "by VAL; players without games are left out")
        XCTAssertEqual(PlayerComparison.search(try league(), query: "spirou", clubNames: { clubs[$0] ?? [] }).map(\.id), [1, 2])
        XCTAssertEqual(PlayerComparison.search(try league(), query: " mine ", clubNames: { clubs[$0] ?? [] }).map(\.id), [3])
    }

    func testSearchIgnoresDiacritics() throws {
        let player = try candidate(1, team: 1, first: "Mohammed", last: "Tlarhi Amrani", games: 2, val: 1)
        XCTAssertEqual(PlayerComparison.search([player], query: "LIÈGE", clubNames: { _ in ["Liege Basket"] }).count, 1)
    }
}
