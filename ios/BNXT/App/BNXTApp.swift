import SwiftUI

@main
struct BNXTApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var versionChecker: VersionChecker

    init() {
        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        // UI tests can pin a policy (Debug only); otherwise the remote config decides (§3.9, §7.24).
        let source: VersionPolicySource = LaunchArguments.testPolicySource(installed: installed) ?? RemoteConfigClient()
        _versionChecker = State(initialValue: VersionChecker(source: source, installedVersion: installed))
    }

    var body: some Scene {
        WindowGroup {
            RootView(versionChecker: versionChecker)
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
                .task { await versionChecker.check() }
                .onChange(of: scenePhase) { _, phase in
                    // Checks on launch and on returning to the foreground, at most every 6 h (§3.9).
                    if phase == .active { Task { await versionChecker.check() } }
                }
        }
    }
}
