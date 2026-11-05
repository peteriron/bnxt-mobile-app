import Foundation

/// A player Search can find: one active roster entry (§3.8). Addressed by roster id, like the player page.
struct SearchPlayer: Identifiable, Hashable, Sendable {
    var id: Int { rosterId }
    let rosterId: Int
    let teamId: Int
    let player: Player
    let position: PlayingPosition?
}

/// Search rules (§3.8): clubs and players matched on device, from the first character.
enum SearchIndex {
    static let playerLimit = 30

    /// Active roster entries of every club, one per roster id.
    static func players(from rosters: [Int: [RosterEntry]]) -> [SearchPlayer] {
        var seen = Set<Int>()
        return rosters.sorted { $0.key < $1.key }.flatMap { teamId, entries in
            entries.filter(\.isActive).compactMap { entry in
                seen.insert(entry.id).inserted
                    ? SearchPlayer(rosterId: entry.id, teamId: teamId, player: entry.player, position: entry.position)
                    : nil
            }
        }
    }

    /// Every word of the query must appear in the name ("jos hea" finds Joshua Heath), ignoring case and accents.
    static func matches(_ text: String, query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return false }
        return words.allSatisfy { text.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// Players whose name matches, surnames starting with the query first, then by surname; at most `playerLimit`.
    static func players(_ players: [SearchPlayer], query: String) -> [SearchPlayer] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        func startsSurname(_ candidate: SearchPlayer) -> Bool {
            candidate.player.lastName.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
        }
        let found = players.filter { matches($0.player.fullName, query: needle) }
        return Array(found.sorted { lhs, rhs in
            let left = startsSurname(lhs), right = startsSurname(rhs)
            if left != right { return left }
            let order = lhs.player.lastName.localizedCaseInsensitiveCompare(rhs.player.lastName)
            return order == .orderedSame ? lhs.rosterId < rhs.rosterId : order == .orderedAscending
        }.prefix(playerLimit))
    }

    /// Clubs matching by display name, official name, city or short code (as on the Clubs tab).
    static func clubs(_ clubs: [Club], query: String) -> [Club] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return [] }
        return clubs.filter { club in
            [club.displayName, club.officialName, club.city ?? "", club.shortName].contains { matches($0, query: needle) }
        }
    }
}
