import Foundation
import Observation

/// The Games tab (§3.3): the full-season schedule, with the game slider's fresher copy of the games around today.
@MainActor @Observable
final class GamesViewModel {
    var mode: GamesList.Mode = .upcoming
    var onlyMyClub = false

    private(set) var games: [Game] = []
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient

    init(api: BNXTAPIClient) {
        self.api = api
    }

    func sections(favoriteId: Int?) -> GamesList.Sections {
        GamesList.sections(games, mode: mode, clubId: onlyMyClub ? favoriteId : nil)
    }

    func load(season: Season) async {
        if games.isEmpty { state = .loading }
        let api = api
        async let sliderRequest = try? api.gameSlider(competitionId: season.competitionId)
        async let scheduleRequest = try? api.schedule(seasonId: season.id, cachePolicy: .maxAge(BNXTAPIClient.scheduleMaxAge))
        let (slider, schedule) = await (sliderRequest, scheduleRequest)
        guard slider != nil || schedule != nil else {
            state = games.isEmpty ? .failed : .loaded
            return
        }
        // The slider first: `GamesList.sections` keeps the first copy of a game.
        games = (slider?.value ?? []) + (schedule?.value ?? [])
        let got: [(any FetchedInfo)?] = [slider, schedule]
        cachedAt = got.compactMap { $0 }.filter(\.isFallback).map(\.fetchedAt).min()
        state = .loaded
    }
}

/// Game detail (§3.4): the game, then what its state needs. Final and live: the box score. Upcoming: both
/// clubs' averages, players and games for the preview. Standings for records and positions in every state.
@MainActor @Observable
final class GameViewModel {
    enum Side: Hashable, Sendable { case home, away }

    let gameId: Int
    var tab: GameDetail.Tab?
    var boxSide: Side = .home

    private(set) var game: Game?
    private(set) var box: BoxScore?
    private(set) var standings: [Int: Standing] = [:]
    private(set) var statistics: [Int: TeamStatistics] = [:]
    private(set) var players: [Int: [PlayerSeasonAverages]] = [:]
    private(set) var teamGames: [Int: [Game]] = [:]
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?
    /// The FIBA LiveStats feed while the game is live (§7.4); its score, period and clock override BNXT's.
    private(set) var liveFeed: LiveFeed?

    @ObservationIgnored private let api: BNXTAPIClient
    @ObservationIgnored private let liveStats: LiveStatsClient
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    /// The game as BNXT sends it; `game` is this with the live feed applied.
    @ObservationIgnored private var bnxtGame: Game?
    @ObservationIgnored private var geniusId: Int?
    @ObservationIgnored private var lookedUpGeniusId = false
    /// Both clubs' rosters, to give the live box score's players their roster ids (loaded once, on the first feed).
    @ObservationIgnored private var liveRosters: [Int: [RosterEntry]]?
    /// The box score built from the feed, shown while BNXT's own is empty.
    private(set) var liveBox: BoxScore?

    /// The box score the tabs show: BNXT's once it has lines, else the live one from the feed.
    var shownBox: BoxScore? {
        if let box, !box.isEmpty { return box }
        return liveBox ?? box
    }

    /// The box score on screen comes from the live feed.
    var isLiveBox: Bool { shownBox != nil && shownBox == liveBox }

    init(gameId: Int, api: BNXTAPIClient, liveStats: LiveStatsClient = LiveStatsClient(),
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.gameId = gameId
        self.api = api
        self.liveStats = liveStats
        self.sleep = sleep
    }

    var tabs: [GameDetail.Tab] { game.map(GameDetail.tabs) ?? [] }
    /// The chosen tab if the game's state still offers it, else the state's first tab.
    var selectedTab: GameDetail.Tab? { tab.flatMap { tabs.contains($0) ? $0 : nil } ?? tabs.first }

    func teamBox(_ side: Side) -> TeamBoxScore? {
        guard let game, let box = shownBox else { return nil }
        let id = side == .home ? game.home.team.id : game.away.team.id
        return box.teams.first { $0.team.id == id } ?? (side == .home ? box.home : box.away)
    }

    func form(teamId: Int) -> [Bool] {
        ClubPage.form(results: ClubPage.results(teamGames[teamId] ?? [], teamId: teamId), teamId: teamId)
    }

    func teamForm(teamId: Int) -> GameDetail.TeamForm {
        GameDetail.teamForm(statistics: statistics[teamId], players: players[teamId] ?? [], gamesPlayed: standings[teamId]?.played ?? 0)
    }

    var earlierMeetings: [Game] {
        guard let game else { return [] }
        return GameDetail.earlierMeetings(of: game, in: teamGames.values.flatMap { $0 })
    }

    func load(season: Season, liveStatsEnabled: Bool = true) async {
        if state != .loaded { state = .loading }
        let api = api, id = gameId, competitionId = season.competitionId
        async let standingsRequest = try? api.standings(competitionId: competitionId, phaseId: season.phaseIds.first ?? 0)
        // A finished game never changes: serve it from the cache when we have it.
        guard let fetchedGame = try? await api.game(id: id, cachePolicy: .cacheFirst) else {
            if let value = await standingsRequest?.value { setStandings(value) }
            state = game == nil ? .failed : .loaded
            return
        }
        apply(fetchedGame.value)
        var sources: [any FetchedInfo] = [fetchedGame]
        let game = fetchedGame.value

        switch game.status {
        case .finished, .inProgress:
            if let fetched = try? await api.boxScore(gameId: id, competitionId: competitionId, isFinal: game.status == .finished,
                                                  settledAt: game.settledAt) {
                box = fetched.value
                sources.append(fetched)
            }
            await coverMissingFinalData(season: season, liveStatsEnabled: liveStatsEnabled)
        case .scheduled:
            await loadPreview(home: game.home.team.id, away: game.away.team.id)
        }
        if let fetched = await standingsRequest {
            setStandings(fetched.value)
            sources.append(fetched)
        }
        cachedAt = sources.filter(\.isFallback).map(\.fetchedAt).min()
        state = .loaded
    }

    // MARK: Live (§7.4, docs/bnxt-api.md "Polling policy")

    /// The feed every 10 s: one request per live screen, only while the screen is visible (the caller's task).
    static let livePollInterval: Duration = .seconds(10)
    /// BNXT's own game (for the final whistle and the box score) every 6th poll with the feed, every 3rd without.
    static func refreshesGame(onPoll poll: Int, liveStatsEnabled: Bool) -> Bool {
        poll > 0 && poll.isMultiple(of: liveStatsEnabled ? 6 : 3)
    }

    /// Polls until the game is no longer live or the caller's task is cancelled (the screen went away).
    func watchLive(season: Season, liveStatsEnabled: Bool) async {
        var poll = 0
        while game?.isLive == true, !Task.isCancelled {
            await refreshLive(season: season, liveStatsEnabled: liveStatsEnabled,
                              refreshGame: Self.refreshesGame(onPoll: poll, liveStatsEnabled: liveStatsEnabled))
            poll += 1
            guard game?.isLive == true else { return }
            do { try await sleep(Self.livePollInterval) } catch { return }
        }
    }

    /// One poll. A failed feed keeps the last one shown; BNXT's score is the fallback when there's none.
    func refreshLive(season: Season, liveStatsEnabled: Bool, refreshGame: Bool) async {
        if liveStatsEnabled, let id = await resolveGeniusId(season: season), let feed = try? await liveStats.feed(geniusId: id) {
            liveFeed = feed
            game = merged()
            if let game = bnxtGame {
                let rosters = await rosters(for: game, season: season)
                liveBox = LiveBoxScore.make(feed, game: game, rosters: rosters)
            }
        } else if !liveStatsEnabled, liveFeed != nil {
            liveFeed = nil // switched off by remote config
            liveBox = nil
            game = merged()
        }
        guard refreshGame, let fetched = try? await api.game(id: gameId) else { return }
        apply(fetched.value)
        if fetched.value.status == .finished {
            await load(season: season, liveStatsEnabled: liveStatsEnabled) // the final box score, cache-first once complete
        } else if let fetchedBox = try? await api.boxScore(gameId: gameId, competitionId: season.competitionId, isFinal: false) {
            box = fetchedBox.value
        }
    }

    /// BNXT says `finished` before it has the quarters and box score (docs/bnxt-api.md). Until then the feed fills
    /// them in, if it agrees on the final score; otherwise, or once BNXT's are in, the feed is dropped.
    private func coverMissingFinalData(season: Season, liveStatsEnabled: Bool) async {
        guard let finished = bnxtGame, finished.status == .finished else { return }
        let hasFinalBox = box?.isEmpty == false
        let isComplete = hasFinalBox && !finished.home.periodScores.isEmpty
        if !isComplete, liveStatsEnabled, let id = await resolveGeniusId(season: season),
           let feed = try? await liveStats.feed(geniusId: id) {
            liveFeed = feed
        }
        if !isComplete, liveStatsEnabled, let liveFeed,
           liveFeed.homeScore == finished.home.score, liveFeed.awayScore == finished.away.score {
            liveBox = hasFinalBox ? nil : LiveBoxScore.make(liveFeed, game: finished, rosters: await rosters(for: finished, season: season))
        } else {
            liveFeed = nil
            liveBox = nil
        }
        game = merged()
    }

    private func rosters(for game: Game, season: Season) async -> [Int: [RosterEntry]] {
        if let liveRosters { return liveRosters }
        let api = api, competitionId = season.competitionId
        let fetched = await BNXTAPIClient.gather([game.home.team.id, game.away.team.id]) {
            try await api.roster(teamId: $0, competitionId: competitionId, cachePolicy: .maxAge(StatsViewModel.maxAge))
        }
        let rosters = fetched.mapValues(\.value)
        if !rosters.isEmpty { liveRosters = rosters } // retried on the next poll if both failed
        return rosters
    }

    /// Only the game slider carries the FIBA id; looked up once per screen.
    private func resolveGeniusId(season: Season) async -> Int? {
        if let geniusId = bnxtGame?.geniusId ?? geniusId { return geniusId }
        guard !lookedUpGeniusId else { return nil }
        lookedUpGeniusId = true
        geniusId = try? await api.gameSlider(competitionId: season.competitionId).value.first { $0.id == gameId }?.geniusId
        return geniusId
    }

    private func apply(_ fetched: Game) {
        bnxtGame = fetched
        game = merged()
    }

    private func merged() -> Game? {
        guard let bnxtGame, let liveFeed else { return bnxtGame }
        switch bnxtGame.status {
        case .inProgress: return bnxtGame.applying(liveFeed)
        case .finished: return bnxtGame.fillingQuarters(from: liveFeed)
        case .scheduled: return bnxtGame
        }
    }

    private func setStandings(_ rows: [Standing]) {
        standings = Dictionary(rows.map { ($0.team.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func loadPreview(home: Int, away: Int) async {
        let api = api
        async let homeTeam = try? api.team(id: home)
        async let awayTeam = try? api.team(id: away)
        async let homePlayers = try? api.playerAverages(teamId: home)
        async let awayPlayers = try? api.playerAverages(teamId: away)
        async let homeGames = try? api.teamGames(teamId: home)
        async let awayGames = try? api.teamGames(teamId: away)
        let teams = await [homeTeam, awayTeam].compactMap { $0?.value }
        for team in teams { if let stats = team.statistics { statistics[team.id] = stats } }
        if let value = await homePlayers?.value { players[home] = value }
        if let value = await awayPlayers?.value { players[away] = value }
        if let value = await homeGames?.value { teamGames[home] = value }
        if let value = await awayGames?.value { teamGames[away] = value }
    }
}
