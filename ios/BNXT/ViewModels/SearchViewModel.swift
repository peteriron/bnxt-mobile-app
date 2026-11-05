import Foundation
import Observation

/// Search (§3.8): every club's roster, loaded once (4 requests at a time, reused for an hour) and searched on device,
/// so typing never costs a request (§7.29). The league's VAL leaders are the suggestions while the field is empty.
@MainActor @Observable
final class SearchViewModel {
    var query = ""

    private(set) var players: [SearchPlayer] = []
    private(set) var leaders: PlayerLeaders?
    private(set) var state: LoadState = .idle
    /// No roster loaded (offline with nothing cached): only clubs can be found.
    private(set) var playersUnavailable = false

    @ObservationIgnored private let api: BNXTAPIClient

    static let suggestionCount = 5

    init(api: BNXTAPIClient) {
        self.api = api
    }

    var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }
    var playerResults: [SearchPlayer] { SearchIndex.players(players, query: query) }
    func clubResults(_ clubs: [Club]) -> [Club] { SearchIndex.clubs(clubs, query: query) }
    var suggestedPlayers: [LeaderEntry] { Array((leaders?[.efficiency] ?? []).prefix(Self.suggestionCount)) }

    func load(season: Season, teamIds: [Int]) async {
        if players.isEmpty { state = .loading }
        let api = api, competitionId = season.competitionId
        async let leaders = try? api.playerLeaders(competitionId: competitionId, phaseId: season.phaseIds.first ?? 0,
                                                   cachePolicy: .maxAge(StatsViewModel.maxAge))
        let rosters = await BNXTAPIClient.gather(teamIds) {
            try await api.roster(teamId: $0, competitionId: competitionId, cachePolicy: .maxAge(StatsViewModel.maxAge))
        }
        if !rosters.isEmpty { players = SearchIndex.players(from: rosters.mapValues(\.value)) }
        playersUnavailable = players.isEmpty && rosters.isEmpty
        // Clubs are searchable from the app's own list, so Search works even when no roster loads.
        state = .loaded
        if let value = await leaders?.value { self.leaders = value }
    }
}
