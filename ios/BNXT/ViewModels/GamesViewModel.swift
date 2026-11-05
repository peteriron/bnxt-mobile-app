import Foundation
import Observation

/// The Games tab (§3.3). Source: the game slider (~30 games around today) until the full-season schedule
/// call is found (§8 Phase 0).
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
        do {
            let fetched = try await api.gameSlider(competitionId: season.competitionId)
            games = fetched.value
            cachedAt = fetched.isFallback ? fetched.fetchedAt : nil
            state = .loaded
        } catch {
            state = games.isEmpty ? .failed : .loaded
        }
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

    @ObservationIgnored private let api: BNXTAPIClient

    init(gameId: Int, api: BNXTAPIClient) {
        self.gameId = gameId
        self.api = api
    }

    var tabs: [GameDetail.Tab] { game.map(GameDetail.tabs) ?? [] }
    /// The chosen tab if the game's state still offers it, else the state's first tab.
    var selectedTab: GameDetail.Tab? { tab.flatMap { tabs.contains($0) ? $0 : nil } ?? tabs.first }

    func teamBox(_ side: Side) -> TeamBoxScore? {
        guard let game, let box else { return nil }
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

    func load(season: Season) async {
        if state != .loaded { state = .loading }
        let api = api, id = gameId, competitionId = season.competitionId
        async let standingsRequest = try? api.standings(competitionId: competitionId, phaseId: season.phaseIds.first ?? 0)
        // A finished game never changes: serve it from the cache when we have it.
        guard let fetchedGame = try? await api.game(id: id, cachePolicy: .cacheFirst) else {
            if let value = await standingsRequest?.value { setStandings(value) }
            state = game == nil ? .failed : .loaded
            return
        }
        game = fetchedGame.value
        var sources: [any FetchedInfo] = [fetchedGame]
        let game = fetchedGame.value

        switch game.status {
        case .finished, .inProgress:
            if let fetched = try? await api.boxScore(gameId: id, competitionId: competitionId, isFinal: game.status == .finished) {
                box = fetched.value
                sources.append(fetched)
            }
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
