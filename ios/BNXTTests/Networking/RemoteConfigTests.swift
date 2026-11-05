@testable import BNXT
import XCTest

/// The committed config/v1/config.json is bundled into the app, so these tests validate what gets published.
/// REQUIREMENTS §3.9: a policy change must pass validation before it's published.
final class RemoteConfigFileTests: XCTestCase {
    private func bundledConfig() throws -> RemoteConfig {
        try XCTUnwrap(RemoteConfig.bundled(), "config.json missing from the app bundle (project.yml resources)")
    }

    func testRepoConfigDecodesCompletely() throws {
        let config = try bundledConfig()

        XCTAssertEqual(config.schemaVersion, RemoteConfig.supportedSchema)
        XCTAssertTrue(config.isCompatible)
        XCTAssertEqual(config.season, Season.current, "config season and the bundled Season.current fallback disagree")
        XCTAssertEqual(config.teams.count, 16)
        XCTAssertEqual(config.teams[537]?.displayName, "Spirou Basket")
        XCTAssertEqual(config.teams[537]?.rgb, RGB(hex: 0xB41B1F))
        XCTAssertEqual(config.zones.map(\.id), ["leader", "be-playoffs", "nl-playoffs"])
        XCTAssertEqual(config.zones.first { $0.id == "be-playoffs" }?.nationalPositionAtMost, 8)
        XCTAssertEqual(config.zones.first { $0.id == "nl-playoffs" }?.country, .netherlands)
        XCTAssertFalse(config.relegation)
        XCTAssertTrue(config.features.liveStats)
        XCTAssertNil(config.apiKeyOverride, "apiKeyOverride publishes a key in the public repo: emergency use only (§7.15)")
    }

    /// §3.5: the brackets must line up with the zones, or the Playoffs view and the table disagree.
    func testPlayoffFormatMatchesThePlayoffZones() throws {
        let config = try bundledConfig()
        let playoffs = try XCTUnwrap(config.playoffs)
        XCTAssertEqual(playoffs.brackets.map(\.country), [.belgium, .netherlands])
        XCTAssertEqual(playoffs.brackets.map(\.seeds), [8, 4])
        XCTAssertEqual(playoffs.brackets[0].rounds.map(\.bestOf), [3, 5, 5])
        XCTAssertEqual(playoffs.brackets[1].rounds.map(\.bestOf), [5, 7])
        for bracket in playoffs.brackets {
            let zone = config.zones.first { $0.country == bracket.country }
            XCTAssertEqual(zone?.nationalPositionAtMost, bracket.seeds, "\(bracket.country) zone and bracket size disagree")
        }
        XCTAssertEqual(config.seasonExplainer(for: "en").count, 2)
        XCTAssertEqual(config.seasonExplainer(for: "nl"), config.seasonExplainer(for: "en"), "falls back to English")
    }

    /// The published policy must be sound and must never block the build that ships it.
    func testRepoVersionPolicyIsSoundAndDoesNotBlockThisBuild() throws {
        let config = try bundledConfig()
        let policy = try XCTUnwrap(config.versionPolicy, "versionPolicy.ios missing")
        XCTAssertNil(policy.problem, policy.problem ?? "")
        XCTAssertNotNil(policy.message(for: "en"))

        let installed = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        let status = VersionEvaluator.evaluate(installed: installed, policy: policy, minimumDataSchema: config.minimumDataSchema)
        XCTAssertFalse(status.isRequired, "config.json would block \(installed): \(status). Never set minimumVersion above the live version.")
        XCTAssertLessThanOrEqual(config.minimumDataSchema, RemoteConfig.dataSchema)
    }

    /// §7.25/§7.26: every club of the season has a display name, a city, its country and a valid brand colour.
    func testEveryClubHasNameCityAndColour() throws {
        let config = try bundledConfig()
        let clubs = try Fixture.list(Team.self, from: "teams")
        XCTAssertEqual(Set(config.teams.keys), Set(clubs.map(\.id)), "config.teams and the season's clubs differ")
        for (id, settings) in config.teams {
            XCTAssertNotNil(settings.displayName, "club \(id) has no displayName")
            XCTAssertNotNil(settings.city, "club \(id) has no city")
            XCTAssertEqual(settings.country, clubs.first { $0.id == id }?.country, "club \(id) country differs from the API")
            XCTAssertNotNil(settings.rgb, "club \(id) colour \(settings.color ?? "nil") isn't #RRGGBB")
        }
    }

    func testNewerSchemaKeepsOnlyTheVersionPolicy() throws {
        let json = #"""
        {"schemaVersion": 99, "season": {"id": 1, "competitionId": 1, "phaseIds": [1], "label": "x", "gamesPerTeam": 1},
         "versionPolicy": {"ios": {"latestVersion": "9.0.0", "minimumVersion": "9.0.0"}, "minimumDataSchema": 2},
         "teams": {"1": {"displayName": "X"}}}
        """#
        let config = try JSONDecoder().decode(RemoteConfig.self, from: Data(json.utf8))

        XCTAssertFalse(config.isCompatible)
        XCTAssertEqual(config.versionPolicy?.minimumVersion, "9.0.0")
        XCTAssertEqual(config.minimumDataSchema, 2)
        XCTAssertNil(config.season)
        XCTAssertTrue(config.teams.isEmpty)
    }

    func testMalformedSectionsFallBackToDefaults() throws {
        let json = #"{"features": "on", "zones": [{"id": "x"}], "teams": [], "versionPolicy": {"ios": 5}}"#
        let config = try JSONDecoder().decode(RemoteConfig.self, from: Data(json.utf8))

        XCTAssertEqual(config.schemaVersion, 1)
        XCTAssertTrue(config.features.liveStats)
        XCTAssertEqual(config.zones, [])
        XCTAssertTrue(config.teams.isEmpty)
        XCTAssertNil(config.versionPolicy)
        XCTAssertNil(config.playoffs)
        XCTAssertEqual(config.seasonExplainer(for: "en"), [])
    }

    func testOneBadBracketDoesNotDropTheOthers() throws {
        let json = #"{"playoffs": {"brackets": [{"country": "XX", "rounds": []}, "#
            + #"{"country": "NL", "label": "NL", "rounds": [{"label": "F", "bestOf": 7}, {"label": 3}]}]}}"#
        let config = try JSONDecoder().decode(RemoteConfig.self, from: Data(json.utf8))
        let brackets = try XCTUnwrap(config.playoffs?.brackets)
        XCTAssertEqual(brackets.map(\.country), [.netherlands])
        XCTAssertEqual(brackets[0].rounds.map(\.bestOf), [7])
        XCTAssertEqual(brackets[0].seeds, 2)
    }
}

final class RemoteConfigClientTests: XCTestCase {
    private var cacheDirectory: URL!
    private let configPath = "/peteriron/bnxt-mobile-app/main/config/v1/config.json"
    private let fixedNow = Date(timeIntervalSince1970: 1_793_750_400)

    override func setUp() {
        MockURLProtocol.router.reset()
        cacheDirectory = FileManager.default.temporaryDirectory.appending(path: "RemoteConfigClientTests-\(UUID().uuidString)")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        MockURLProtocol.router.reset()
    }

    private func client(bundled: RemoteConfig? = nil) -> RemoteConfigClient {
        let now = fixedNow
        return RemoteConfigClient(session: MockURLProtocol.session(), cache: ResponseCache(directory: cacheDirectory),
                                  bundled: { bundled }, now: { now }, bundledOnly: false)
    }

    private func configJSON(latest: String) -> Data {
        Data(#"{"schemaVersion":1,"versionPolicy":{"ios":{"latestVersion":"\#(latest)","minimumVersion":"0.1.0"}}}"#.utf8)
    }

    func testLoadsFromTheNetworkAndCachesIt() async throws {
        MockURLProtocol.router.stub(configPath, body: configJSON(latest: "1.5.0"))

        let loadedResult = await client().load()
        let loaded = try XCTUnwrap(loadedResult)

        XCTAssertEqual(loaded.source, .network)
        XCTAssertEqual(loaded.value.versionPolicy?.latestVersion, "1.5.0")
        XCTAssertEqual(MockURLProtocol.router.requests.first?.url?.host(), "raw.githubusercontent.com")
    }

    func testFallsBackToTheCacheThenTheBundle() async throws {
        let bundled = try XCTUnwrap(RemoteConfig.bundled())
        MockURLProtocol.router.stub(configPath, body: configJSON(latest: "1.5.0"))
        _ = await client(bundled: bundled).load()

        MockURLProtocol.router.fail(configPath)
        let offlineResult = await client(bundled: bundled).load()
        let offline = try XCTUnwrap(offlineResult)
        XCTAssertEqual(offline.source, .cache)
        XCTAssertEqual(offline.value.versionPolicy?.latestVersion, "1.5.0")

        try FileManager.default.removeItem(at: cacheDirectory)
        let firstLaunchOfflineResult = await client(bundled: bundled).load()
        let firstLaunchOffline = try XCTUnwrap(firstLaunchOfflineResult)
        XCTAssertEqual(firstLaunchOffline.source, .bundled)
        XCTAssertEqual(firstLaunchOffline.value, bundled)
    }

    /// A broken file on the server (HTML error page, truncated JSON) must not replace a good cached copy.
    func testInvalidResponseIsNotCached() async throws {
        MockURLProtocol.router.stub(configPath, body: configJSON(latest: "1.5.0"))
        _ = await client().load()

        MockURLProtocol.router.stub(configPath, body: Data("<html>rate limited</html>".utf8))
        let loadedResult = await client().load()
        let loaded = try XCTUnwrap(loadedResult)

        XCTAssertEqual(loaded.source, .cache)
        XCTAssertEqual(loaded.value.versionPolicy?.latestVersion, "1.5.0")
    }

    func testServesAsAVersionPolicySource() async throws {
        MockURLProtocol.router.stub(configPath, body: configJSON(latest: "1.5.0"))
        let snapshotResult = await client().currentPolicy()
        let snapshot = try XCTUnwrap(snapshotResult)
        XCTAssertEqual(snapshot.policy?.minimumVersion, "0.1.0")
        XCTAssertEqual(snapshot.minimumDataSchema, 1)
    }

    func testNothingAnywhereGivesNil() async {
        MockURLProtocol.router.fail(configPath)
        let loaded = await client(bundled: nil).load()
        XCTAssertNil(loaded)
    }
}
