import XCTest

/// REQUIREMENTS §3.6 and §3.7: the Stats tab and Compare players, against the live API.
final class StatsUITests: UITestCase {
    private func openStats() {
        tab(3).tap()
        XCTAssertTrue(element("screen.stats").waitForExistence(timeout: 5))
    }

    func testPlayersShowALeaderAndRanksPerCategory() {
        openStats()
        // The leaders response is ~1.4 MB and can take ~10 s.
        XCTAssertTrue(element("stats.leader").waitForExistence(timeout: 30), "leaders didn't load")
        XCTAssertTrue(element("stats.players").exists)

        element("stats.category.assist").tap()
        XCTAssertTrue(element("stats.category.assist").isSelected)
        XCTAssertTrue(element("stats.leader").label.contains("Assists"), element("stats.leader").label)

        element("stats.leader").tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'screen.player.'"))
            .firstMatch.waitForExistence(timeout: 5))
    }

    func testTeamsRankClubsAndOpenTheClub() {
        openStats()
        app.segmentedControls["stats.segment"].buttons["Teams"].tap()
        let teams = element("stats.teams")
        XCTAssertTrue(teams.waitForExistence(timeout: 30), "team stats didn't load")

        element("stats.teamCategory.pointsAllowed").tap()
        XCTAssertTrue(element("stats.teamCategory.pointsAllowed").isSelected)

        let spirou = element("stats.team.CHA")
        XCTAssertTrue(spirou.waitForExistence(timeout: 5))
        XCTAssertTrue(spirou.value as? String ?? "" != "", "a value is read out")
        spirou.tap()
        XCTAssertTrue(element("screen.club.537").waitForExistence(timeout: 5))
    }

    func testCompareFromStatsAndPickAPlayer() {
        openStats()
        element("stats.compare").tap()
        XCTAssertTrue(element("screen.compare").waitForExistence(timeout: 5))
        let slotA = element("compare.slot.a"), slotB = element("compare.slot.b")
        XCTAssertTrue(slotA.waitForExistence(timeout: 30), "players didn't load")
        XCTAssertTrue(element("compare.row.points").exists)
        XCTAssertTrue(element("compare.row.gamesPlayed").exists)
        XCTAssertNotEqual(slotA.value as? String, slotB.value as? String, "two different players by default")

        slotB.tap()
        XCTAssertTrue(element("compare.picker").waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Heath\n") // Return dismisses the keyboard before the next tap
        let heath = element("compare.option.11173")
        XCTAssertTrue(heath.waitForExistence(timeout: 5))
        heath.tap()

        XCTAssertFalse(element("compare.picker").waitForExistence(timeout: 2))
        XCTAssertTrue((slotB.value as? String ?? "").contains("Heath"), slotB.value as? String ?? "")
    }
}

/// §3.7: "Compare with another player" on a player page pre-fills slot A.
final class CompareFromPlayerUITests: UITestCase {
    override var extraLaunchArguments: [String] { ["--uitest-open", "bnxt://player/11173"] }

    func testPlayerPagePrefillsA() {
        XCTAssertTrue(element("player.averages").waitForExistence(timeout: 15), "player didn't load")
        let compare = element("player.compare")
        for _ in 0..<4 where !compare.isHittable { app.swipeUp() }
        compare.tap()

        let slotA = element("compare.slot.a")
        XCTAssertTrue(slotA.waitForExistence(timeout: 30))
        XCTAssertTrue((slotA.value as? String ?? "").contains("Heath"), slotA.value as? String ?? "")
    }
}
