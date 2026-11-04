@testable import BNXT
import XCTest

final class GameTimeTests: XCTestCase {
    private func utc(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    /// Summer time (CEST, UTC+2) applies before the 25 Oct 2026 switch.
    func testParsesSummerTime() throws {
        XCTAssertEqual(GameTime.parse("2026-10-23 20:30:00"), try utc("2026-10-23T18:30:00Z"))
    }

    /// Winter time (CET, UTC+1) applies after the switch.
    func testParsesWinterTime() throws {
        XCTAssertEqual(GameTime.parse("2026-11-05 20:30:00"), try utc("2026-11-05T19:30:00Z"))
    }

    func testRejectsMalformedInput() {
        let inputs = [
            "", "2026-10-23", "2026-10-23T20:30:00", "2026-13-01 20:00:00",
            "2026-02-30 20:00:00", "20:30:00 2026-10-23", "abcd-ef-gh 20:30:00"
        ]
        for input in inputs {
            XCTAssertNil(GameTime.parse(input), "Expected nil for \"\(input)\"")
        }
    }
}

final class SeasonTests: XCTestCase {
    func testCurrentSeasonMatchesVerifiedIds() {
        XCTAssertEqual(Season.current.competitionId, 25)
        XCTAssertEqual(Season.current.phaseIds, [183])
        XCTAssertEqual(Season.current.gamesPerTeam, 30)
    }

    func testMapsUpstreamCountryIds() {
        XCTAssertEqual(Country(upstreamClubId: 1), .belgium)
        XCTAssertEqual(Country(upstreamClubId: 2), .netherlands)
        XCTAssertNil(Country(upstreamClubId: 3))
    }
}
