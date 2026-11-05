import Foundation

/// Display rules shared by components, as pure functions so they're unit-testable.
/// Times are always shown in league time (Europe/Brussels), wherever the fan is.
enum Format {
    /// "20:30"
    static func tipOffTime(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: GameTime.leagueTimeZone))
    }

    /// "Today", "Tomorrow", "Yesterday", a weekday within the next 6 days, else "Thu 5 Nov".
    static func relativeDay(_ date: Date, now: Date, locale: Locale = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GameTime.leagueTimeZone
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return String(localized: "Today")
        case 1: return String(localized: "Tomorrow")
        case -1: return String(localized: "Yesterday")
        case 2...6:
            return date.formatted(Date.FormatStyle(locale: locale, timeZone: GameTime.leagueTimeZone).weekday(.wide))
        default:
            return date.formatted(Date.FormatStyle(locale: locale, timeZone: GameTime.leagueTimeZone).weekday(.abbreviated).day().month(.abbreviated))
        }
    }

    /// A per-game average: one decimal ("7.8").
    static func average(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    /// A box-score count: whole number ("13"). Minutes are floored like the official box score.
    static func count(_ value: Double) -> String {
        Int(value.rounded(.down)).formatted()
    }

    /// "+13", "−5", "0"
    static func plusMinus(_ value: Double) -> String {
        let whole = Int(value.rounded())
        return whole > 0 ? "+\(whole)" : whole < 0 ? "−\(abs(whole))" : "0"
    }

    /// "6-13" made-attempted.
    static func madeAttempted(_ made: Double, _ attempted: Double) -> String {
        "\(Int(made))-\(Int(attempted))"
    }

    /// "W5", "L2"
    static func streak(_ streak: Streak) -> String {
        "\(streak.isWinning ? "W" : "L")\(streak.count)"
    }

    /// "Won 5 in a row" / "Lost 1", for VoiceOver.
    static func streakDescription(_ streak: Streak) -> String {
        streak.isWinning ? String(localized: "won \(streak.count) in a row") : String(localized: "lost \(streak.count) in a row")
    }

    /// A percentage rounded to whole numbers ("44%"), or "–" when nothing was attempted.
    static func percentage(_ value: Double?) -> String {
        guard let value else { return "–" }
        return "\(Int(value.rounded()))%"
    }
}

/// What a game row or header shows in its status slot.
enum GameStatusLabel: Equatable {
    case live(period: String?)
    case final
    case scheduled(time: String)

    init(game: Game, locale: Locale = .current) {
        switch game.status {
        case .finished: self = .final
        case .inProgress: self = .live(period: game.period)
        case .scheduled: self = .scheduled(time: Format.tipOffTime(game.tipOff, locale: locale))
        }
    }
}
