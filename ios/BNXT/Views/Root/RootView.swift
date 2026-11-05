import SwiftUI

/// The five tabs (REQUIREMENTS §7.2). Order matters: UI tests address tabs by index.
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

/// The app shell: tabs with one navigation stack each, onboarding until a club is picked,
/// settings, and the version checker's banner and blocking screen.
struct RootView: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let router: Router
    let versionChecker: VersionChecker

    @State private var showsSettings = false
    @State private var replayingOnboarding = false

    private var needsOnboarding: Bool { favorites.clubId == nil || replayingOnboarding }

    var body: some View {
        ZStack {
            tabs
                .accessibilityHidden(needsOnboarding || versionChecker.status.isRequired)

            if needsOnboarding {
                OnboardingView(appModel: appModel) { club in
                    favorites.choose(club)
                    withAnimation { replayingOnboarding = false }
                    router.selectedTab = .home
                }
                .transition(.opacity)
            }

            // §3.9: a required update covers everything, onboarding included, and can't be dismissed.
            if versionChecker.status.isRequired {
                UpdateRequiredView(policy: versionChecker.policy)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: versionChecker.status)
        .animation(.default, value: needsOnboarding)
        .sheet(isPresented: $showsSettings) {
            SettingsView(appModel: appModel, favorites: favorites) {
                withAnimation { replayingOnboarding = true }
            }
        }
    }

    private var tabs: some View {
        TabView(selection: Binding(get: { router.selectedTab }, set: { router.reselect($0) })) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    NavigationStack(path: Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })) {
                        root(for: tab)
                            .navigationDestination(for: Route.self) { route in
                                RouteDestination(route: route, appModel: appModel)
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func root(for tab: AppTab) -> some View {
        switch tab {
        case .home:
            PlaceholderScreen(title: tab.title) { homeHeader }
                .accessibilityElement(children: .contain) // identifier must not leak onto children
                .accessibilityIdentifier("screen.home")
                .safeAreaInset(edge: .top) { updateBanner }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showsSettings = true } label: { Image(systemName: "person.crop.circle") }
                            .accessibilityLabel("Settings")
                            .accessibilityIdentifier("home.settings")
                    }
                }
        case .standings:
            StandingsScreen(appModel: appModel, favorites: favorites) { router.push(.club(id: $0)) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen.standings")
        default:
            PlaceholderScreen(title: tab.title)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen.\(tab.rawValue)")
        }
    }

    @ViewBuilder private var homeHeader: some View {
        if let club = favorites.resolve(in: appModel.clubs) {
            Button { router.push(.club(id: club.id)) } label: {
                HStack(spacing: 12) {
                    ClubLogo(club: club, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My club")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.lime)
                        Text(verbatim: club.displayName)
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.myClub")
        }
    }

    @ViewBuilder private var updateBanner: some View {
        if versionChecker.showsUpdateBanner, case let .updateAvailable(latest) = versionChecker.status {
            UpdateBanner(latest: latest, storeURL: versionChecker.policy?.storeURL) {
                withAnimation { versionChecker.dismissBanner() }
            }
        }
    }
}
