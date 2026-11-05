import Foundation
import Observation

/// The supporter's club (REQUIREMENTS §3.1, §7.8), in `UserDefaults` only (§7.16).
///
/// Competition-team ids change every season (§7.14), so the short name is stored too: when the id is gone,
/// `resolve(in:)` finds the club again by short name and adopts its new id.
@MainActor @Observable
final class FavoriteClubStore {
    struct Saved: Codable, Equatable, Sendable {
        var teamId: Int
        var shortName: String
    }

    private(set) var saved: Saved?

    @ObservationIgnored private let defaults: UserDefaults
    static let key = "favoriteClub"

    var clubId: Int? { saved?.teamId }

    init(defaults: UserDefaults = .standard, resetState: Bool = LaunchArguments.resetState(), preset: Saved? = nil) {
        self.defaults = defaults
        if let preset {
            saved = preset
        } else if !resetState, let data = defaults.data(forKey: Self.key) {
            saved = try? JSONDecoder().decode(Saved.self, from: data)
        }
    }

    func choose(_ club: Club) {
        save(Saved(teamId: club.id, shortName: club.shortName))
    }

    func clear() {
        saved = nil
        defaults.removeObject(forKey: Self.key)
    }

    /// The favourite among `clubs`, re-linking by short name after a season change.
    func resolve(in clubs: [Club]) -> Club? {
        guard let saved else { return nil }
        if let club = clubs.first(where: { $0.id == saved.teamId }) { return club }
        guard let renewed = clubs.first(where: { $0.shortName == saved.shortName }) else { return nil }
        save(Saved(teamId: renewed.id, shortName: renewed.shortName))
        return renewed
    }

    private func save(_ value: Saved) {
        saved = value
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: Self.key) }
    }
}
