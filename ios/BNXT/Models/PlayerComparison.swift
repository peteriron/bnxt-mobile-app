import Foundation

/// A player who can be compared (§3.7): their per-game season averages and the club they're listed under.
struct CompareCandidate: Identifiable, Hashable, Sendable {
    var id: Int { averages.rosterId }
    let averages: PlayerSeasonAverages
    let teamId: Int

    var player: Player { averages.player }
    var gamesPlayed: Int { averages.gamesPlayed }
    var perGame: StatLine { averages.perGame }
}

/// The 12 compared stats, in display order (§3.7).
enum CompareStat: String, CaseIterable, Identifiable, Sendable {
    case points, rebounds, assists, steals, blocks, turnovers
    case fieldGoalPercentage, threePointPercentage, freeThrowPercentage
    case efficiency, minutes, gamesPlayed

    var id: Self { self }

    var lowerIsBetter: Bool { self == .turnovers }

    var isPercentage: Bool {
        switch self {
        case .fieldGoalPercentage, .threePointPercentage, .freeThrowPercentage: true
        default: false
        }
    }

    /// nil for a percentage with no attempts.
    func value(_ candidate: CompareCandidate) -> Double? {
        let line = candidate.perGame
        switch self {
        case .fieldGoalPercentage: return line.fieldGoalPercentage
        case .threePointPercentage: return line.threePointPercentage
        case .freeThrowPercentage: return line.freeThrowPercentage
        case .gamesPlayed: return Double(candidate.gamesPlayed)
        default: return perGame.map { line[keyPath: $0] }
        }
    }

    /// The per-game average a counting stat reads.
    private var perGame: KeyPath<StatLine, Double>? {
        switch self {
        case .points: \.points
        case .rebounds: \.rebounds
        case .assists: \.assists
        case .steals: \.steals
        case .blocks: \.blocks
        case .turnovers: \.turnovers
        case .efficiency: \.efficiency
        case .minutes: \.minutes
        default: nil
        }
    }

    /// A full bar (prototype scale); bigger values are clamped. Games are out of the season's games per team.
    func scale(gamesPerTeam: Int) -> Double {
        switch self {
        case .points: 30
        case .rebounds: 12
        case .assists: 8
        case .steals: 3
        case .blocks: 2.5
        case .turnovers: 5
        case .fieldGoalPercentage, .threePointPercentage, .freeThrowPercentage: 100
        case .efficiency: 30
        case .minutes: 40
        case .gamesPlayed: Double(max(gamesPerTeam, 1))
        }
    }

    /// As shown: whole percentages, whole games, one decimal otherwise.
    func formatted(_ value: Double?) -> String {
        guard let value else { return "–" }
        if isPercentage { return Format.percentage(value) }
        if self == .gamesPlayed { return Format.count(value) }
        return Format.average(value)
    }
}

/// Pure rules for Compare players (§3.7).
enum PlayerComparison {
    /// Slot A (violet) and slot B (orange); raw values name them in accessibility identifiers.
    enum Side: String, Hashable, Sendable, CaseIterable { case first = "a", second = "b" }

    /// Which side's value is better, judged on the values as shown so "7.8 vs 7.8" highlights neither.
    /// nil when equal or when either value is missing.
    static func better(_ stat: CompareStat, first: Double?, second: Double?) -> Side? {
        guard let first, let second else { return nil }
        let precision = stat.isPercentage || stat == .gamesPlayed ? 1.0 : 10.0
        let shownFirst = (first * precision).rounded(), shownSecond = (second * precision).rounded()
        guard shownFirst != shownSecond else { return nil }
        return (shownFirst > shownSecond) != stat.lowerIsBetter ? .first : .second
    }

    /// Players who've played, best VAL first (ties by surname): the picker's order.
    static func byEfficiency(_ candidates: [CompareCandidate]) -> [CompareCandidate] {
        candidates.filter { $0.gamesPlayed > 0 }.sorted { lhs, rhs in
            if lhs.perGame.efficiency != rhs.perGame.efficiency { return lhs.perGame.efficiency > rhs.perGame.efficiency }
            return lhs.player.lastName.localizedCaseInsensitiveCompare(rhs.player.lastName) == .orderedAscending
        }
    }

    /// Players who've played at least half the games of the player with the most (rounded up), so one big game
    /// doesn't make a "leader". The league's own rankings apply similar rules (§7.28).
    static func qualified(_ candidates: [CompareCandidate]) -> [CompareCandidate] {
        let ranked = byEfficiency(candidates)
        let most = ranked.map(\.gamesPlayed).max() ?? 0
        let threshold = (most + 1) / 2
        return ranked.filter { $0.gamesPlayed >= threshold }
    }

    /// Default slots (§3.7): A = the preset player if known, else the favourite club's top player by VAL, else the league's;
    /// B = the league VAL leader, or the next one if that's A.
    static func defaults(_ candidates: [CompareCandidate], favoriteClubId: Int?, preset: Int?) -> (first: Int?, second: Int?) {
        let ranked = byEfficiency(candidates), qualified = qualified(candidates)
        let presetId = preset.flatMap { id in candidates.contains { $0.id == id } ? id : nil }
        let clubBest = favoriteClubId.flatMap { club in
            (qualified.first { $0.teamId == club } ?? ranked.first { $0.teamId == club })?.id
        }
        let first = presetId ?? clubBest ?? qualified.first?.id ?? ranked.first?.id
        let second = (qualified.first { $0.id != first } ?? ranked.first { $0.id != first })?.id
        return (first, second)
    }

    /// Puts `rosterId` in `side`. Picking the player already in the other slot swaps the two.
    static func choose(_ rosterId: Int, for side: Side, current: (first: Int?, second: Int?)) -> (first: Int?, second: Int?) {
        switch side {
        case .first: (rosterId, current.second == rosterId ? current.first : current.second)
        case .second: (current.first == rosterId ? current.second : current.first, rosterId)
        }
    }

    /// The picker's list: players matching `query` by name or club (any of `clubNames`), best VAL first.
    static func search(_ candidates: [CompareCandidate], query: String, clubNames: (Int) -> [String]) -> [CompareCandidate] {
        let ranked = byEfficiency(candidates)
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return ranked }
        func matches(_ text: String) -> Bool { text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return ranked.filter { candidate in
            matches(candidate.player.fullName) || clubNames(candidate.teamId).contains(where: matches)
        }
    }
}
