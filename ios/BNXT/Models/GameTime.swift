import Foundation

/// Parses upstream tip-off times.
///
/// The API sends `"YYYY-MM-DD HH:mm:ss"` in local league time with no zone
/// (docs/bnxt-api.md, "Field mapping"). Belgium and the Netherlands share
/// `Europe/Brussels` time, including daylight saving time.
enum GameTime {
    static let leagueTimeZone = TimeZone(identifier: "Europe/Brussels") ?? .gmt

    /// Returns `nil` for anything that isn't exactly `YYYY-MM-DD HH:mm:ss` or isn't a real date.
    static func parse(_ string: String) -> Date? {
        let parts = string.split(separator: " ")
        guard parts.count == 2 else { return nil }
        let date = parts[0].split(separator: "-").compactMap { Int($0) }
        let time = parts[1].split(separator: ":").compactMap { Int($0) }
        guard date.count == 3, time.count == 3 else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = leagueTimeZone
        let components = DateComponents(year: date[0], month: date[1], day: date[2],
                                        hour: time[0], minute: time[1], second: time[2])
        guard components.isValidDate(in: calendar) else { return nil }
        return calendar.date(from: components)
    }
}
