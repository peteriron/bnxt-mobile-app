import Foundation

/// Pure derivations for the club page (§3.8), so the ordering and fallback rules are unit-tested.
enum ClubPage {
    /// One roster line: the entry, its jersey (from a box score, since rosters often send ""), and points per game.
    struct RosterRow: Identifiable, Hashable, Sendable {
        var id: Int { entry.id }
        let entry: RosterEntry
        let jersey: String?
        let pointsPerGame: Double?
    }

    /// Active players by jersey number; players without a number last, then by surname.
    static func roster(_ entries: [RosterEntry], jerseys: [Int: String], averages: [PlayerSeasonAverages]) -> [RosterRow] {
        let points = Dictionary(averages.map { ($0.rosterId, $0.perGame.points) }, uniquingKeysWith: { first, _ in first })
        return entries
            .filter(\.isActive)
            .map { entry in
                let jersey = [entry.jersey, jerseys[entry.player.id]].compactMap { $0 }.first { !$0.isEmpty }
                return RosterRow(entry: entry, jersey: jersey, pointsPerGame: points[entry.id])
            }
            .sorted { lhs, rhs in
                let left = lhs.jersey.flatMap(Int.init) ?? Int.max, right = rhs.jersey.flatMap(Int.init) ?? Int.max
                if left != right { return left < right }
                return lhs.entry.player.lastName.localizedCaseInsensitiveCompare(rhs.entry.player.lastName) == .orderedAscending
            }
    }

    /// Jersey number per player id, from box scores (newest first wins).
    static func jerseys(from boxScores: [BoxScore], teamId: Int) -> [Int: String] {
        var result: [Int: String] = [:]
        for box in boxScores {
            for line in box.teams.first(where: { $0.team.id == teamId })?.players ?? [] {
                if let jersey = line.jersey, !jersey.isEmpty, result[line.player.id] == nil { result[line.player.id] = jersey }
            }
        }
        return result
    }

    /// Finished games, newest first.
    static func results(_ games: [Game], teamId: Int) -> [Game] {
        games.filter { $0.status == .finished && $0.involves(teamId) }.sorted { $0.tipOff > $1.tipOff }
    }

    /// Games still to play (or in progress), soonest first.
    static func upcoming(_ games: [Game], teamId: Int) -> [Game] {
        games.filter { $0.status != .finished && $0.involves(teamId) }.sorted { $0.tipOff < $1.tipOff }
    }

    /// The last five results, oldest first (as `FormStrip` shows them).
    static func form(results: [Game], teamId: Int, count: Int = 5) -> [Bool] {
        results.prefix(count).reversed().compactMap { game in game.winner.map { $0.id == teamId } }
    }

    /// The home arena: from the most recent home game that names one.
    static func arena(games: [Game], teamId: Int) -> String? {
        games.filter { $0.home.team.id == teamId }
            .sorted { $0.tipOff > $1.tipOff }
            .lazy.compactMap { $0.arena?.isEmpty == false ? $0.arena : nil }.first
    }

    /// Sortable columns of the "Player stats" table.
    enum StatColumn: String, CaseIterable, Identifiable, Sendable {
        case minutes = "MIN", points = "PTS", rebounds = "REB", assists = "AST"
        case steals = "STL", blocks = "BLK", turnovers = "TO", efficiency = "VAL"

        var id: Self { self }

        func value(_ line: StatLine) -> Double {
            switch self {
            case .minutes: line.minutes
            case .points: line.points
            case .rebounds: line.rebounds
            case .assists: line.assists
            case .steals: line.steals
            case .blocks: line.blocks
            case .turnovers: line.turnovers
            case .efficiency: line.efficiency
            }
        }
    }

    /// Players who have played, highest first in `column`; ties by surname.
    static func playerStats(_ averages: [PlayerSeasonAverages], sortedBy column: StatColumn) -> [PlayerSeasonAverages] {
        averages.filter { $0.gamesPlayed > 0 }.sorted { lhs, rhs in
            let left = column.value(lhs.perGame), right = column.value(rhs.perGame)
            if left != right { return left > right }
            return lhs.player.lastName.localizedCaseInsensitiveCompare(rhs.player.lastName) == .orderedAscending
        }
    }
}

extension Game {
    func involves(_ teamId: Int) -> Bool { home.team.id == teamId || away.team.id == teamId }
}

/// IOC country codes (as the API sends them) to a flag and an English name. Unknown codes show as the code.
enum Nationality {
    private static let iso: [String: String] = [
        "USA": "US", "BEL": "BE", "NED": "NL", "FRA": "FR", "GER": "DE", "ESP": "ES", "ITA": "IT", "GBR": "GB", "IRL": "IE",
        "CAN": "CA", "AUS": "AU", "FIN": "FI", "SWE": "SE", "DEN": "DK", "NOR": "NO", "SUI": "CH", "AUT": "AT", "POR": "PT",
        "GRE": "GR", "SLO": "SI", "CRO": "HR", "SRB": "RS", "BIH": "BA", "MNE": "ME", "MKD": "MK", "BUL": "BG", "ROU": "RO",
        "HUN": "HU", "POL": "PL", "CZE": "CZ", "SVK": "SK", "LAT": "LV", "LTU": "LT", "EST": "EE", "UKR": "UA", "GEO": "GE",
        "TUR": "TR", "ISR": "IL", "ANG": "AO", "NGR": "NG", "SEN": "SN", "CMR": "CM", "COD": "CD", "MLI": "ML", "CIV": "CI",
        "MAR": "MA", "TUN": "TN", "EGY": "EG", "RSA": "ZA", "BRA": "BR", "ARG": "AR", "DOM": "DO", "PUR": "PR", "JAM": "JM",
        "BAH": "BS", "MEX": "MX", "SUR": "SR", "CUW": "CW", "ARU": "AW", "JPN": "JP", "CHN": "CN", "NZL": "NZ", "LUX": "LU",
        "ISL": "IS", "CPV": "CV", "GUI": "GN", "GHA": "GH", "KEN": "KE", "SSD": "SS", "SUD": "SD", "CAF": "CF", "GAB": "GA"
    ]

    /// ISO 3166 alpha-2 for an IOC code, or nil when unknown.
    static func isoCode(ioc: String) -> String? { iso[ioc.uppercased()] }

    /// "🇺🇸" for "USA"; nil when unknown.
    static func flag(ioc: String) -> String? {
        guard let code = isoCode(ioc: ioc) else { return nil }
        return String(String.UnicodeScalarView(code.unicodeScalars.compactMap { Unicode.Scalar(0x1F1A5 + $0.value) }))
    }

    /// "United States" for "USA" (in the user's language); the code itself when unknown.
    static func name(ioc: String, locale: Locale = .current) -> String {
        isoCode(ioc: ioc).flatMap { locale.localizedString(forRegionCode: $0) } ?? ioc
    }
}
