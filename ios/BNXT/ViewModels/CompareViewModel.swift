import Foundation
import Observation

/// Compare players (§3.7, §7.7): two players' season averages side by side.
/// Candidates come from every club's player averages (one request per club, at most 4 at a time).
@MainActor @Observable
final class CompareViewModel {
    /// Pre-fills slot A ("Compare with another player" on a player page).
    let presetRosterId: Int?

    private(set) var candidates: [CompareCandidate] = []
    private(set) var slotA: Int?
    private(set) var slotB: Int?
    private(set) var state: LoadState = .idle
    private(set) var cachedAt: Date?

    @ObservationIgnored private let api: BNXTAPIClient

    init(presetRosterId: Int?, api: BNXTAPIClient) {
        self.presetRosterId = presetRosterId
        self.api = api
    }

    var playerA: CompareCandidate? { candidate(slotA) }
    var playerB: CompareCandidate? { candidate(slotB) }

    func candidate(_ rosterId: Int?) -> CompareCandidate? {
        guard let rosterId else { return nil }
        return candidates.first { $0.id == rosterId }
    }

    func player(on side: PlayerComparison.Side) -> CompareCandidate? {
        side == .first ? playerA : playerB
    }

    func choose(_ rosterId: Int, for side: PlayerComparison.Side) {
        (slotA, slotB) = PlayerComparison.choose(rosterId, for: side, current: (slotA, slotB))
    }

    func load(season: Season, teamIds: [Int], favoriteClubId: Int?, refresh: Bool = false) async {
        if candidates.isEmpty { state = .loading }
        let api = api, policy: BNXTAPIClient.CachePolicy = refresh ? .networkFirst : .maxAge(StatsViewModel.maxAge)
        let fetched = await BNXTAPIClient.gather(teamIds) { try await api.playerAverages(teamId: $0, cachePolicy: policy) }
        if !fetched.isEmpty {
            // A player who moved clubs mid-season is listed by both; keep the entry with more games.
            var byRoster: [Int: CompareCandidate] = [:]
            for (teamId, list) in fetched {
                for averages in list.value {
                    let candidate = CompareCandidate(averages: averages, teamId: teamId)
                    if let known = byRoster[candidate.id], known.gamesPlayed >= candidate.gamesPlayed { continue }
                    byRoster[candidate.id] = candidate
                }
            }
            candidates = byRoster.values.sorted { $0.id < $1.id }
            cachedAt = fetched.values.filter(\.isFallback).map(\.fetchedAt).min()
        }
        // Keep the user's picks across a refresh; fill empty or unknown slots with the defaults.
        let defaults = PlayerComparison.defaults(candidates, favoriteClubId: favoriteClubId, preset: presetRosterId)
        if candidate(slotA) == nil { slotA = defaults.first }
        if candidate(slotB) == nil || slotB == slotA { slotB = defaults.second == slotA ? nil : defaults.second }
        state = candidates.isEmpty ? .failed : .loaded
    }
}
