import Foundation
import Observation

/// The player page (§3.8): bio, season averages with league ranks, shooting, points chart and game log.
@MainActor @Observable
final class PlayerViewModel {
    let rosterId: Int

    private(set) var entry: RosterEntry?
    private(set) var lines: [PlayerGameLine] = []
    private(set) var leaders: PlayerLeaders?
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient
    @ObservationIgnored private let now: () -> Date

    init(rosterId: Int, api: BNXTAPIClient, now: @escaping () -> Date = Date.init) {
        self.rosterId = rosterId
        self.api = api
        self.now = now
    }

    var season: PlayerPage.SeasonStats? { PlayerPage.season(lines) }
    var log: [PlayerPage.LogRow] { PlayerPage.log(lines) }
    var jersey: String? { PlayerPage.jersey(entry: entry, lines: lines) }
    var age: Int? { entry?.player.age(on: now()) }
    /// The club: the roster entry's, else the team of the latest game.
    var teamId: Int? { entry?.teamId ?? log.first?.line.teamId }

    func rank(_ category: LeaderCategory) -> Int? {
        PlayerPage.leagueRank(leaders, rosterId: rosterId, category: category)
    }

    /// How long the leaders (a slow 1.4 MB response) are reused before they're fetched again.
    static let leadersMaxAge: TimeInterval = 3600

    /// Bio and game log first; the rank badges follow when the slow leaders response arrives.
    func load(season: Season) async {
        if state != .loaded { state = .loading }
        let api = api, id = rosterId
        async let leaders = try? api.playerLeaders(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0,
                                                   cachePolicy: .maxAge(Self.leadersMaxAge))
        async let entry = try? api.rosterEntry(id: id)
        async let log = try? api.playerGameLog(rosterId: id)
        let fetched = await (entry: entry, log: log)

        if let value = fetched.entry?.value { self.entry = value }
        if let value = fetched.log?.value { lines = value }
        let all: [(any FetchedInfo)?] = [fetched.entry, fetched.log]
        cachedAt = all.compactMap { $0 }.filter(\.isFallback).map(\.fetchedAt).min()
        state = self.entry == nil && lines.isEmpty ? .failed : .loaded

        if let value = await leaders?.value { self.leaders = value }
    }
}
