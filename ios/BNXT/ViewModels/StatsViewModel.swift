import Foundation
import Observation

/// The Stats tab (§3.6): league leaders per category (Players) and club rankings built from team game lists (Teams).
/// Each half loads when it's first shown; Teams costs one request per club, so it waits until it's picked.
@MainActor @Observable
final class StatsViewModel {
    enum Mode: Hashable, Sendable { case players, teams }

    var mode: Mode = .players
    var playerCategory: LeaderCategory = .efficiency
    var teamCategory: TeamStatCategory = .points

    private(set) var leaders: PlayerLeaders?
    private(set) var leadersState: LoadState = .idle
    private(set) var leadersCachedAt: Date?

    private(set) var teamStats: [TeamSeasonStats] = []
    private(set) var teamsState: LoadState = .idle
    private(set) var teamsCachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient

    /// Leaders (1.4 MB, ~10 s) and the 16 team game lists change only after game nights; reuse them this long.
    /// Pull to refresh always asks the network.
    static let maxAge: TimeInterval = 3600

    init(api: BNXTAPIClient) {
        self.api = api
    }

    var playerRows: [StatsBoard.PlayerRow] { StatsBoard.playerRows(leaders, category: playerCategory) }
    var teamRows: [StatsBoard.TeamRow] { StatsBoard.teamRows(teamStats, category: teamCategory) }

    var state: LoadState { mode == .players ? leadersState : teamsState }
    var cachedAt: Date? { mode == .players ? leadersCachedAt : teamsCachedAt }

    /// Loads the shown half if it hasn't been loaded yet.
    func loadIfNeeded(season: Season, teamIds: [Int]) async {
        switch mode {
        case .players where leadersState == .idle: await loadLeaders(season: season, refresh: false)
        case .teams where teamsState == .idle: await loadTeams(season: season, teamIds: teamIds, refresh: false)
        default: break
        }
    }

    func refresh(season: Season, teamIds: [Int]) async {
        switch mode {
        case .players: await loadLeaders(season: season, refresh: true)
        case .teams: await loadTeams(season: season, teamIds: teamIds, refresh: true)
        }
    }

    func loadLeaders(season: Season, refresh: Bool) async {
        if leaders == nil { leadersState = .loading }
        do {
            let fetched = try await api.playerLeaders(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0,
                                                      cachePolicy: refresh ? .networkFirst : .maxAge(Self.maxAge))
            leaders = fetched.value
            leadersCachedAt = fetched.isFallback ? fetched.fetchedAt : nil
            leadersState = .loaded
        } catch {
            leadersState = leaders == nil ? .failed : .loaded
        }
    }

    func loadTeams(season: Season, teamIds: [Int], refresh: Bool) async {
        if teamStats.isEmpty { teamsState = .loading }
        let api = api, policy: BNXTAPIClient.CachePolicy = refresh ? .networkFirst : .maxAge(Self.maxAge)
        let fetched = await BNXTAPIClient.gather(teamIds) { try await api.teamGames(teamId: $0, cachePolicy: policy) }
        if !fetched.isEmpty {
            teamStats = fetched.compactMap { id, games in TeamSeasonStats.from(games.value, teamId: id, phaseIds: season.phaseIds) }
            teamsCachedAt = fetched.values.filter(\.isFallback).map(\.fetchedAt).min()
        }
        teamsState = fetched.isEmpty && teamStats.isEmpty ? .failed : .loaded
    }
}
