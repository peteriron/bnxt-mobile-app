import SwiftUI

/// Home (§3.2), built around the favourite club: live card, next game and last result, standing, club leaders,
/// around the league and the league's VAL leaders.
struct HomeScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void
    let onSelectTab: (AppTab) -> Void

    @State private var model: HomeViewModel

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelect: @escaping (Route) -> Void, onSelectTab: @escaping (AppTab) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelect = onSelect
        self.onSelectTab = onSelectTab
        _model = State(initialValue: HomeViewModel(api: appModel.api))
    }

    private var club: Club? { favorites.resolve(in: appModel.clubs) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 240)
                case .failed:
                    LoadFailedView { Task { await load() } }
                case .loaded:
                    if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
                    content
                }
            }
            .padding(.vertical)
        }
        .background(Theme.ink)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task(id: club?.id) { await load() }
        // Live polling only while Home is visible and my club is playing (§4 Network etiquette).
        .task(id: model.liveGame?.id) {
            if model.liveGame != nil {
                await model.watchLive(season: appModel.season, liveStatsEnabled: appModel.config?.features.liveStats ?? true)
            }
        }
    }

    private func load() async {
        await model.load(season: appModel.season, clubId: club?.id)
    }

    private func club(_ team: Team) -> Club {
        appModel.club(id: team.id) ?? Club(team: team, settings: appModel.config?.teams[team.id])
    }

    // MARK: Header

    @ViewBuilder private var header: some View {
        if let club {
            Button { onSelect(.club(id: club.id)) } label: {
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
                            .oneLineUnlessAccessibilitySize()
                            .minimumScaleFactor(0.7)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("home.myClub")
        }
    }

    // MARK: Content

    @ViewBuilder private var content: some View {
        if let live = model.liveGame {
            Button { onSelect(.game(id: live.id)) } label: {
                LiveCard(game: live, home: club(live.home.team), away: club(live.away.team), lastPlay: model.lastPlay)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .accessibilityIdentifier("home.live")
        }
        if model.nextGame != nil || model.lastResult != nil {
            AdaptiveStack(spacing: 10) {
                if let next = model.nextGame { nextCard(next) }
                if let last = model.lastResult { lastCard(last) }
            }
            .padding(.horizontal)
        }
        if let summary = model.standing(config: appModel.config, clubs: appModel.clubs) {
            section("Standing", action: ("Full table", { onSelectTab(.standings) })) {
                HomeStandingCard(summary: summary, clubId: club?.id, club: { club($0) }, action: { onSelectTab(.standings) })
            }
        }
        if !model.clubLeaders.isEmpty, let club {
            section("Club leaders", action: ("Roster", { onSelect(.club(id: club.id)) })) {
                HomeClubLeaders(leaders: model.clubLeaders, onSelect: onSelect)
            }
        }
        if !model.aroundTheLeague.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Around the league", actionTitle: "All games") { onSelectTab(.games) }
                    .padding(.horizontal)
                HomeAroundTheLeague(games: model.aroundTheLeague, now: model.now(), club: { club($0) }, onSelect: onSelect)
            }
        }
        if !model.leagueLeaders.isEmpty {
            section("League leaders", action: ("See all", { onSelectTab(.stats) })) {
                HomeLeagueLeaders(entries: model.leagueLeaders, club: { club($0) }, onSelect: onSelect)
            }
        }
    }

    private func section(_ title: LocalizedStringKey, action: (LocalizedStringKey, () -> Void),
                         @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, actionTitle: action.0, action: action.1)
            content()
        }
        .padding(.horizontal)
    }

    // MARK: Next game and last result

    private func opponent(in game: Game) -> (team: Team, isHome: Bool) {
        let isHome = game.home.team.id == club?.id
        return (isHome ? game.away.team : game.home.team, isHome)
    }

    private func nextCard(_ game: Game) -> some View {
        let (team, isHome) = opponent(in: game)
        let opponent = club(team)
        return Button { onSelect(.game(id: game.id)) } label: {
            miniCard(title: "Next game", opponent: opponent, isHome: isHome) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: HomePage.countdown(to: game.tipOff, now: model.now()))
                        .font(Theme.score(.title3))
                        .foregroundStyle(Theme.textPrimary)
                        .oneLineUnlessAccessibilitySize()
                        .minimumScaleFactor(0.7)
                    Text(verbatim: Self.nextGameDetail(game.tipOff, now: model.now()))
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.next")
    }

    /// "20:30" today or tomorrow (the countdown already says which), else "Thu 12 Nov · 20:30".
    static func nextGameDetail(_ tipOff: Date, now: Date) -> String {
        let time = Format.tipOffTime(tipOff)
        return HomePage.daysUntil(tipOff, now: now) <= 1 ? time : "\(Format.relativeDay(tipOff, now: now)) · \(time)"
    }

    private func lastCard(_ game: Game) -> some View {
        let (team, isHome) = opponent(in: game)
        let opponent = club(team)
        let own = isHome ? game.home.score : game.away.score, other = isHome ? game.away.score : game.home.score
        let won = game.winner.map { $0.id == club?.id }
        return Button { onSelect(.game(id: game.id)) } label: {
            miniCard(title: "Last result", opponent: opponent, isHome: isHome) {
                HStack(spacing: 8) {
                    if let won {
                        Text(won ? "W" : "L")
                            .font(.caption.weight(.heavy))
                            .frame(width: 24, height: 24)
                            .foregroundStyle(won ? Theme.win : Theme.loss)
                            .background((won ? Theme.win : Theme.loss).opacity(Theme.badgeTintOpacity), in: RoundedRectangle(cornerRadius: 7))
                    }
                    Text(verbatim: "\(own ?? 0)–\(other ?? 0)")
                        .font(Theme.score(.title3))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.last")
    }

    private func miniCard(title: LocalizedStringKey, opponent: Club, isHome: Bool, @ViewBuilder detail: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
            HStack(spacing: 8) {
                ClubLogo(club: opponent, size: 30)
                Text(verbatim: "\(isHome ? "vs" : "@") \(opponent.shortName)")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(isHome ? String(localized: "versus") : String(localized: "at")) \(opponent.displayName)"))
            detail()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
    }
}
