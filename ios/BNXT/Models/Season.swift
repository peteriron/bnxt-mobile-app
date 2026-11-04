import Foundation

/// Identifies one BNXT League season in the upstream API.
///
/// Competition and phase IDs change every summer (REQUIREMENTS.md §7.14), so they're
/// configuration. `current` is the bundled fallback.
struct Season: Hashable, Codable, Sendable {
    /// Upstream season id: the year the season ends (2027 for 2026-27).
    let id: Int
    let competitionId: Int
    let phaseIds: [Int]
    let label: String
    let gamesPerTeam: Int

    /// BNXT League 2026-27, regular season (verified against the API on 3 Nov 2026).
    static let current = Season(id: 2027, competitionId: 25, phaseIds: [183], label: "2026-27", gamesPerTeam: 30)
}

/// The two countries in the league.
enum Country: String, CaseIterable, Codable, Sendable {
    case belgium = "BE"
    case netherlands = "NL"

    /// The upstream API models countries as "clubs": 1 = Belgium, 2 = Netherlands.
    init?(upstreamClubId: Int) {
        switch upstreamClubId {
        case 1: self = .belgium
        case 2: self = .netherlands
        default: return nil
        }
    }
}
