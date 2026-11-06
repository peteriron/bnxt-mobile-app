import Foundation
import Observation

/// The club page (§3.8): team facts, roster, games and player stats for one club.
/// Each request may fail on its own; the page shows what it got and only fails when it got nothing.
@MainActor @Observable
final class ClubViewModel {
    enum Tab: Hashable, CaseIterable, Sendable { case roster, games, stats }

    let clubId: Int
    var tab: Tab = .roster
    var statSort: ClubPage.StatColumn = .points

    private(set) var team: Team?
    private(set) var standing: Standing?
    private(set) var rosterRows: [ClubPage.RosterRow] = []
    private(set) var averages: [PlayerSeasonAverages] = []
    private(set) var results: [Game] = []
    private(set) var upcoming: [Game] = []
    private(set) var arena: String?
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient

    init(clubId: Int, api: BNXTAPIClient) {
        self.clubId = clubId
        self.api = api
    }

    var form: [Bool] { ClubPage.form(results: results, teamId: clubId) }
    var playerStats: [PlayerSeasonAverages] { ClubPage.playerStats(averages, sortedBy: statSort) }

    func load(season: Season) async {
        if state != .loaded { state = .loading }
        let api = api, id = clubId
        async let team = try? api.team(id: id)
        async let standings = try? api.standings(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0)
        async let roster = try? api.roster(teamId: id, competitionId: season.competitionId)
        async let averages = try? api.playerAverages(teamId: id)
        async let finished = try? api.teamGames(teamId: id)
        async let slider = try? api.gameSlider(competitionId: season.competitionId)
        async let schedule = try? api.schedule(seasonId: season.id, teamId: id, cachePolicy: .maxAge(BNXTAPIClient.scheduleMaxAge))
        let fetched = await (team: team, standings: standings, roster: roster, averages: averages, finished: finished, slider: slider,
                             schedule: schedule)

        if let value = fetched.team?.value { self.team = value }
        if let value = fetched.standings?.value { standing = value.first { $0.team.id == id } }
        if let value = fetched.averages?.value { self.averages = value }
        // The schedule last: `unique` keeps the first unfinished copy, so the fresher slider wins.
        let games = (fetched.finished?.value ?? []) + (fetched.slider?.value ?? []) + (fetched.schedule?.value ?? [])
        if fetched.finished != nil || fetched.slider != nil || fetched.schedule != nil {
            results = ClubPage.results(Self.unique(games), teamId: id)
            upcoming = ClubPage.upcoming(Self.unique(games), teamId: id)
            arena = ClubPage.arena(games: games, teamId: id) ?? arena
        }

        // Rosters often have no jersey numbers; the latest box score has them (docs/bnxt-api.md).
        var jerseys: [Int: String] = [:]
        if let latest = results.first, let box = try? await api.boxScore(gameId: latest.id, competitionId: season.competitionId, isFinal: true,
                                                                         settledAt: latest.settledAt) {
            jerseys = ClubPage.jerseys(from: [box.value], teamId: id)
        }
        if let roster = fetched.roster?.value {
            rosterRows = ClubPage.roster(roster, jerseys: jerseys, averages: self.averages)
        }

        let all: [(any FetchedInfo)?] = [fetched.team, fetched.standings, fetched.roster, fetched.averages, fetched.finished, fetched.slider, fetched.schedule]
        let got = all.compactMap { $0 }
        cachedAt = got.filter(\.isFallback).map(\.fetchedAt).min()
        if got.isEmpty {
            state = self.team == nil && rosterRows.isEmpty ? .failed : .loaded
        } else {
            state = .loaded
        }
    }

    /// The slider and the team's game list overlap; keep the most recent copy of each game.
    private static func unique(_ games: [Game]) -> [Game] {
        var seen: [Int: Game] = [:]
        for game in games where seen[game.id] == nil || game.status == .finished { seen[game.id] = game }
        return Array(seen.values)
    }
}

/// Lets a screen ask any `Fetched` value where it came from without knowing its type.
protocol FetchedInfo {
    var isFallback: Bool { get }
    var fetchedAt: Date { get }
}

extension Fetched: FetchedInfo {}
