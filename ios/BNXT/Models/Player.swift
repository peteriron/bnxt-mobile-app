import Foundation

/// A player's public league profile.
///
/// Privacy (REQUIREMENTS §7.16): the API also sends `facebook`, `twitter`, `instagram` and `description`; they have
/// no property here, so they're never decoded. The birth date is held only to compute an age and is never shown.
/// `PrivacyTests` lists this type's properties with `Mirror` so nobody adds them back.
struct Player: Identifiable, Hashable, Sendable, Decodable {
    let id: Int
    let firstName: String
    let lastName: String
    /// IOC-style code ("USA", "NED"); nil when the API sends an empty string.
    let nationalityCode: String?
    let birthDate: BirthDate?
    let photo: RemoteImage?

    var fullName: String { firstName.isEmpty ? lastName : "\(firstName) \(lastName)" }
    /// "J. Heath", as in box scores.
    var shortName: String { firstName.isEmpty ? lastName : "\(firstName.prefix(1)). \(lastName)" }

    private enum CodingKeys: String, CodingKey {
        case id, birthdate
        case firstName = "first_name", lastName = "last_name"
        case nationalityCode = "nationality_code"
        case photo = "profile_image"
    }

    init(id: Int, firstName: String, lastName: String, nationalityCode: String? = nil,
         birthDate: BirthDate? = nil, photo: RemoteImage? = nil) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.nationalityCode = nationalityCode
        self.birthDate = birthDate
        self.photo = photo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(id: try container.requiredInteger(forKey: .id),
                  firstName: container.text(forKey: .firstName) ?? "",
                  lastName: try container.requiredText(forKey: .lastName),
                  nationalityCode: container.text(forKey: .nationalityCode),
                  birthDate: container.text(forKey: .birthdate).flatMap(BirthDate.init(string:)),
                  photo: container.lenient(RemoteImage.self, forKey: .photo))
    }

    /// Age in whole years on `date` (league time zone), or nil without a birth date.
    func age(on date: Date) -> Int? {
        guard let birthDate else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GameTime.leagueTimeZone
        let today = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = today.year, let month = today.month, let day = today.day else { return nil }
        let hadBirthday = (month, day) >= (birthDate.month, birthDate.day)
        return year - birthDate.year - (hadBirthday ? 0 : 1)
    }
}

/// A calendar date without a time or zone ("1994-12-28").
struct BirthDate: Hashable, Sendable {
    let year: Int, month: Int, day: Int

    init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        (year, month, day) = (parts[0], parts[1], parts[2])
    }
}

/// Basketball positions; the API sends combinations joined by "-" ("small_forward-power_forward").
enum Position: String, CaseIterable, Sendable {
    case pointGuard = "point_guard"
    case shootingGuard = "shooting_guard"
    case smallForward = "small_forward"
    case powerForward = "power_forward"
    case center

    var abbreviation: String {
        switch self {
        case .pointGuard: "PG"
        case .shootingGuard: "SG"
        case .smallForward: "SF"
        case .powerForward: "PF"
        case .center: "C"
        }
    }
}

/// One or more positions, as the API lists them.
struct PlayingPosition: Hashable, Sendable, Decodable {
    let positions: [Position]

    /// "SF/PF"
    var abbreviation: String { positions.map(\.abbreviation).joined(separator: "/") }

    init?(apiName: String) {
        let positions = apiName.split(separator: "-").compactMap { Position(rawValue: String($0)) }
        guard !positions.isEmpty else { return nil }
        self.positions = positions
    }

    private enum CodingKeys: String, CodingKey { case name }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let name = container.text(forKey: .name), let value = PlayingPosition(apiName: name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Unknown position"))
        }
        self = value
    }
}

/// A player on a team's roster for one competition (`roster/team-players`).
/// `id` is the **roster id**, which the player game-log and career endpoints take (docs/bnxt-api.md).
struct RosterEntry: Identifiable, Hashable, Sendable, Decodable {
    let id: Int
    let teamId: Int
    /// Often empty in rosters; box scores carry the real number.
    let jersey: String?
    let heightCm: Int?
    let weightKg: Int?
    let isActive: Bool
    let position: PlayingPosition?
    let player: Player

    private enum CodingKeys: String, CodingKey {
        case id, jersey, height, weight, active, player
        case teamId = "competition_team_id"
        case position = "player_position"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.requiredInteger(forKey: .id)
        teamId = container.integer(forKey: .teamId) ?? 0
        jersey = container.text(forKey: .jersey)
        heightCm = container.integer(forKey: .height)
        weightKg = container.integer(forKey: .weight)
        isActive = container.lenient(Bool.self, forKey: .active) ?? true
        position = container.lenient(PlayingPosition.self, forKey: .position)
        player = try container.decode(Player.self, forKey: .player)
    }
}
