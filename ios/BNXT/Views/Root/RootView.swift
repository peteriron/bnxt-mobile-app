import SwiftUI

/// The five tabs (REQUIREMENTS.md §7.2). Order matters: UI tests address tabs by index.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, games, standings, stats, clubs

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .games: "Games"
        case .standings: "Standings"
        case .stats: "Stats"
        case .clubs: "Clubs"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .games: "basketball.fill"
        case .standings: "chart.bar.fill"
        case .stats: "chart.line.uptrend.xyaxis"
        case .clubs: "shield.fill"
        }
    }
}

struct RootView: View {
    let versionChecker: VersionChecker
    @State private var selection: AppTab = .home

    var body: some View {
        ZStack {
            TabView(selection: $selection) {
                ForEach(AppTab.allCases) { tab in
                    Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                        NavigationStack {
                            PlaceholderScreen(title: tab.title)
                                .accessibilityElement(children: .contain) // identifier must not leak onto children
                                .accessibilityIdentifier("screen.\(tab.rawValue)")
                                .safeAreaInset(edge: .top) {
                                    if tab == .home { updateBanner }
                                }
                        }
                    }
                }
            }
            .accessibilityHidden(versionChecker.status.isRequired)

            // §3.9: a required update covers everything and can't be dismissed.
            if versionChecker.status.isRequired {
                UpdateRequiredView(policy: versionChecker.policy)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: versionChecker.status)
    }

    @ViewBuilder private var updateBanner: some View {
        if versionChecker.showsUpdateBanner, case let .updateAvailable(latest) = versionChecker.status {
            UpdateBanner(latest: latest, storeURL: versionChecker.policy?.storeURL) {
                withAnimation { versionChecker.dismissBanner() }
            }
        }
    }
}

#Preview("Update available") {
    let checker = VersionChecker(source: StaticPolicySource(snapshot: PolicySnapshot(policy: VersionPolicy(latestVersion: "9.0.0"))),
                                 installedVersion: "1.0.0", resetState: true)
    RootView(versionChecker: checker)
        .preferredColorScheme(.dark)
        .task { await checker.check(force: true) }
}

#Preview("Update required") {
    let checker = VersionChecker(source: StaticPolicySource(snapshot: PolicySnapshot(policy: VersionPolicy(latestVersion: "9.0.0",
                                                                                                           minimumVersion: "9.0.0"))),
                                 installedVersion: "1.0.0", resetState: true)
    RootView(versionChecker: checker)
        .preferredColorScheme(.dark)
        .task { await checker.check(force: true) }
}
