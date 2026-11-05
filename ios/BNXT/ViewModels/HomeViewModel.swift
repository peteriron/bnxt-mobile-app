import Foundation
import Observation

/// Home (§3.2): the favourite club's live or next game, last result, standing and leaders, plus the latest
/// round and the league's VAL leaders. Each request may fail on its own; Home only fails when it got nothing.
@MainActor @Observable
final class HomeViewModel {
    private(set) var clubId: Int?
    private(set) var standings: [Standing] = []
    private(set) var slider: [Game] = []
    private(set) var clubGames: [Game] = []
    private(set) var averages: [PlayerSeasonAverages] = []
    private(set) var leaders: PlayerLeaders?
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?
    /// The FIBA feed of my club's live game (§7.4): score, clock and last play on the live card.
    private(set) var liveFeed: (gameId: Int, feed: LiveFeed)?

    @ObservationIgnored private let api: BNXTAPIClient
    @ObservationIgnored private let liveStats: LiveStatsClient
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored let now: () -> Date

    init(api: BNXTAPIClient, liveStats: LiveStatsClient = LiveStatsClient(), now: @escaping () -> Date = Date.init,
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.api = api
        self.liveStats = liveStats
        self.now = now
        self.sleep = sleep
    }

    /// The slider plus the club's own finished games (the slider only reaches ~2 weeks back).
    private var allGames: [Game] { slider + clubGames }

    /// With the feed's score and "Q3 07:42" when it has one.
    var liveGame: Game? {
        guard let game = clubId.flatMap({ HomePage.liveGame(slider, clubId: $0) }) else { return nil }
        guard let liveFeed, liveFeed.gameId == game.id else { return game }
        return game.applying(liveFeed.feed)
    }

    /// "J. Heath · 3PT made" under the live score.
    var lastPlay: String? {
        guard let liveFeed, liveFeed.gameId == liveGame?.id else { return nil }
        return liveFeed.feed.lastPlay?.line
    }
    /// Scheduled games only, so a game in progress shows as the live card instead.
    var nextGame: Game? { clubId.flatMap { HomePage.nextGame(slider, clubId: $0) } }
    var lastResult: Game? { clubId.flatMap { HomePage.lastResult(allGames, clubId: $0) } }
    var aroundTheLeague: [Game] { HomePage.aroundTheLeague(slider) }
    var clubLeaders: [HomePage.ClubLeader] { HomePage.clubLeaders(averages) }
    var leagueLeaders: [LeaderEntry] { HomePage.leagueLeaders(leaders) }

    func standing(config: RemoteConfig?, clubs: [Club]) -> HomePage.StandingSummary? {
        guard let clubId else { return nil }
        let table = StandingsTable(standings: standings, zones: config?.zones ?? [],
                                   countries: Dictionary(clubs.compactMap { club in club.country.map { (club.id, $0) } },
                                                         uniquingKeysWith: { first, _ in first }))
        return HomePage.standing(table, clubId: clubId)
    }

    /// Club data first; the league leaders (a slow 1.4 MB response, reused for an hour) follow.
    func load(season: Season, clubId: Int?) async {
        if clubId != self.clubId {
            // A new favourite: drop the old club's data so it never shows under the new name.
            self.clubId = clubId
            clubGames = []
            averages = []
            state = .loading
        } else if state != .loaded {
            state = .loading
        }
        let api = api
        async let leaders = try? api.playerLeaders(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0,
                                                   cachePolicy: .maxAge(StatsViewModel.maxAge))
        async let standings = try? api.standings(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0)
        async let slider = try? api.gameSlider(competitionId: season.competitionId)
        async let games = Self.request(clubId) { try await api.teamGames(teamId: $0) }
        async let averages = Self.request(clubId) { try await api.playerAverages(teamId: $0) }
        let fetched = await (standings: standings, slider: slider, games: games, averages: averages)
        guard clubId == self.clubId else { return } // the favourite changed while loading

        if let value = fetched.standings?.value { self.standings = value }
        if let value = fetched.slider?.value { self.slider = value }
        if let value = fetched.games?.value { clubGames = value }
        if let value = fetched.averages?.value { self.averages = value }
        let all: [(any FetchedInfo)?] = [fetched.standings, fetched.slider, fetched.games, fetched.averages]
        let got = all.compactMap { $0 }
        cachedAt = got.filter(\.isFallback).map(\.fetchedAt).min()
        let hasData = !self.standings.isEmpty || !self.slider.isEmpty || !clubGames.isEmpty || !self.averages.isEmpty
        state = hasData ? .loaded : .failed

        if let value = await leaders?.value { self.leaders = value }
    }

    /// A club request, or nil without a club or on failure.
    private nonisolated static func request<Value: Sendable>(_ clubId: Int?,
                                                             _ call: @Sendable (Int) async throws -> Value) async -> Value? {
        guard let clubId else { return nil }
        return try? await call(clubId)
    }

    // MARK: Live

    /// Polls my club's live game while Home is visible (the caller's task): the feed every 10 s, the game slider
    /// every 6th poll to notice the final whistle. Ends when the game is no longer live or the task is cancelled.
    func watchLive(season: Season, liveStatsEnabled: Bool) async {
        var poll = 0
        while let game = liveGame, !Task.isCancelled {
            if GameViewModel.refreshesGame(onPoll: poll, liveStatsEnabled: liveStatsEnabled),
               let fetched = try? await api.gameSlider(competitionId: season.competitionId) {
                slider = fetched.value
                guard liveGame != nil else { break } // the final whistle: no more feed requests
            }
            if liveStatsEnabled, let geniusId = game.geniusId, let feed = try? await liveStats.feed(geniusId: geniusId) {
                liveFeed = (game.id, feed)
            } else if !liveStatsEnabled {
                liveFeed = nil
            }
            poll += 1
            guard liveGame != nil else { break }
            do { try await sleep(GameViewModel.livePollInterval) } catch { return }
        }
        liveFeed = nil
    }
}
