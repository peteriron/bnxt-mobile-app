@testable import BNXT
import XCTest

final class FormattingTests: XCTestCase {
    private let english = Locale(identifier: "en_GB")

    private func date(_ text: String) throws -> Date { try XCTUnwrap(GameTime.parse(text)) }

    /// Tip-off times are league time wherever the fan is.
    func testTipOffIsShownInLeagueTime() throws {
        XCTAssertEqual(Format.tipOffTime(try date("2026-11-05 20:30:00"), locale: english), "20:30")
    }

    func testRelativeDays() throws {
        let now = try date("2026-11-05 10:00:00") // Thursday
        XCTAssertEqual(Format.relativeDay(try date("2026-11-05 20:30:00"), now: now, locale: english), "Today")
        XCTAssertEqual(Format.relativeDay(try date("2026-11-06 20:30:00"), now: now, locale: english), "Tomorrow")
        XCTAssertEqual(Format.relativeDay(try date("2026-11-04 20:30:00"), now: now, locale: english), "Yesterday")
        XCTAssertEqual(Format.relativeDay(try date("2026-11-08 15:00:00"), now: now, locale: english), "Sunday")
        XCTAssertEqual(Format.relativeDay(try date("2026-11-14 20:30:00"), now: now, locale: english), "Sat 14 Nov")
    }

    /// Late games stay on their own league day even near midnight.
    func testRelativeDayUsesLeagueMidnight() throws {
        let now = try date("2026-11-05 23:59:00")
        XCTAssertEqual(Format.relativeDay(try date("2026-11-06 00:01:00"), now: now, locale: english), "Tomorrow")
    }

    func testNumbers() {
        XCTAssertEqual(Format.average(7.8), Double(7.8).formatted(.number.precision(.fractionLength(1))))
        XCTAssertEqual(Format.count(31.9), "31")
        XCTAssertEqual(Format.plusMinus(13), "+13")
        XCTAssertEqual(Format.plusMinus(-5), "−5")
        XCTAssertEqual(Format.plusMinus(0), "0")
        XCTAssertEqual(Format.madeAttempted(6, 13), "6-13")
        XCTAssertEqual(Format.percentage(44.48), "44%")
        XCTAssertEqual(Format.percentage(nil), "–")
    }

    func testGameStatusLabel() throws {
        let finished = try Fixture.decode(Envelope<Game>.self, from: "game_11323").data
        let upcoming = try Fixture.decode(Envelope<Game>.self, from: "game_11351_upcoming").data
        let live = Game(id: 1, tipOff: finished.tipOff, status: .inProgress(raw: "live"), home: finished.home, away: finished.away, period: "Q3")

        XCTAssertEqual(GameStatusLabel(game: finished), .final)
        XCTAssertEqual(GameStatusLabel(game: upcoming, locale: english), .scheduled(time: "20:30"))
        XCTAssertEqual(GameStatusLabel(game: live), .live(period: "Q3"))
    }

    func testBoxScoreOrderAndColumns() throws {
        let box = try XCTUnwrap(try Fixture.decode(Envelope<BoxScore>.self, from: "box_score_11323").data.away)
        let ordered = BoxScoreTable.orderedLines(box)

        XCTAssertEqual(ordered.prefix(5).filter(\.isStarter).count, 5, "starters first")
        XCTAssertTrue(zip(ordered.dropFirst(5), ordered.dropFirst(6)).allSatisfy { $0.stats.minutes >= $1.stats.minutes }, "then by minutes")
        XCTAssertTrue(BoxScoreTable.columns(showPlusMinus: true).contains { $0.id == "pm" })
        XCTAssertFalse(BoxScoreTable.columns(showPlusMinus: false).contains { $0.id == "pm" })
        XCTAssertEqual(BoxScoreTable.columns(showPlusMinus: false).last?.id, "val")
    }
}
