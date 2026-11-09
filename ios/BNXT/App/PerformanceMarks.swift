import os

/// Signpost intervals for the performance targets in REQUIREMENTS §4, read by Instruments and by the performance tests
/// (`XCTOSSignpostMetric`). Cheap when nothing is recording.
/// - `LaunchToHome`: the app starts until Home shows its content (target: under 1.5 s from the cache).
/// - `OpenGame`: the game screen appears until its content shows (target: a finished game under 300 ms from the cache).
@MainActor
enum PerformanceMarks {
    static let subsystem = "com.pjproductions.bnxt"
    static let category = "Performance"

    private static let signposter = OSSignposter(subsystem: subsystem, category: category)
    private static var launch: OSSignpostIntervalState?
    private static var game: OSSignpostIntervalState?

    static func appStarted() {
        launch = signposter.beginInterval("LaunchToHome")
    }

    /// Only the first time: later Home reloads aren't launches.
    static func homeShown() {
        guard let state = launch else { return }
        signposter.endInterval("LaunchToHome", state)
        launch = nil
    }

    static func gameScreenAppeared() {
        game = signposter.beginInterval("OpenGame")
    }

    static func gameContentShown() {
        guard let state = game else { return }
        signposter.endInterval("OpenGame", state)
        game = nil
    }
}
