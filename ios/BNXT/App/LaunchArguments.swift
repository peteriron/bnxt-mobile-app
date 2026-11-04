import Foundation

/// Launch arguments used by UI tests (ios/SETUP.md, "UI tests").
/// Stores check `resetState` and skip loading persisted state for that launch,
/// instead of clearing `UserDefaults` and reading it straight back (which races).
enum LaunchArguments {
    static let resetStateFlag = "--uitest-reset-state"

    static func resetState(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains(resetStateFlag)
    }
}
