import SwiftUI

@main
struct BNXTApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appModel = AppModel()
    @State private var favorites: FavoriteClubStore
    @State private var router = Router()
    @State private var versionChecker: VersionChecker

    init() {
        // Logos and photos are re-used everywhere; give AsyncImage a real disk cache.
        URLCache.shared = URLCache(memoryCapacity: 20 << 20, diskCapacity: 150 << 20)

        let installed = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        // UI tests can pin a policy (Debug only); otherwise the remote config decides (§3.9, §7.24).
        let source: VersionPolicySource = LaunchArguments.testPolicySource(installed: installed) ?? RemoteConfigClient()
        _versionChecker = State(initialValue: VersionChecker(source: source, installedVersion: installed))
        _favorites = State(initialValue: FavoriteClubStore(preset: LaunchArguments.presetFavoriteClub()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(appModel: appModel, favorites: favorites, router: router, versionChecker: versionChecker)
                .preferredColorScheme(.dark)
                .tint(Theme.lime)
                .task {
                    if let url = LaunchArguments.openURL() { router.open(url) }
                    await appModel.load()
                    _ = favorites.resolve(in: appModel.clubs) // re-link the favourite after a season change
                }
                .task { await versionChecker.check() }
                .onOpenURL { router.open($0) }
                .onChange(of: scenePhase) { _, phase in
                    // Checks on launch and on returning to the foreground, at most every 6 h (§3.9).
                    if phase == .active { Task { await versionChecker.check() } }
                }
        }
    }
}
