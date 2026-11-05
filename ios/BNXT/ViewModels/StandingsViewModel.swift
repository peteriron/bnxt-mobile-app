import Foundation
import Observation

/// What a screen's data is doing. `failed` only when there's nothing (not even a cached copy) to show.
enum LoadState: Equatable, Sendable {
    case idle, loading, loaded, failed
}

/// The Standings tab (§3.5): loads the regular-season table and keeps the selected view.
@MainActor @Observable
final class StandingsViewModel {
    enum Segment: Hashable, CaseIterable, Sendable {
        case league, belgium, netherlands, playoffs

        var scope: StandingsScope? {
            switch self {
            case .league: .league
            case .belgium: .country(.belgium)
            case .netherlands: .country(.netherlands)
            case .playoffs: nil
            }
        }
    }

    var segment: Segment = .league
    private(set) var standings: [Standing] = []
    private(set) var state: LoadState = .idle
    /// Set when the shown table came from the cache because the network failed.
    private(set) var cachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient

    init(api: BNXTAPIClient) {
        self.api = api
    }

    func load(season: Season) async {
        if standings.isEmpty { state = .loading }
        do {
            let fetched = try await api.standings(competitionId: season.competitionId, phaseId: season.phaseIds.first ?? 0)
            standings = fetched.value
            cachedAt = fetched.isFromCache ? fetched.fetchedAt : nil
            state = .loaded
        } catch {
            // A failed refresh keeps what's on screen.
            state = standings.isEmpty ? .failed : .loaded
        }
    }

    /// The table with zones from `config` and countries filled in from the clubs.
    func table(config: RemoteConfig?, clubs: [Club]) -> StandingsTable {
        StandingsTable(standings: standings, zones: config?.zones ?? [],
                       countries: Dictionary(clubs.compactMap { club in club.country.map { (club.id, $0) } }, uniquingKeysWith: { first, _ in first }))
    }
}
