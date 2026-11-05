import SwiftUI

/// The Games tab (§3.3): Upcoming / Results, All clubs / my club, grouped by day, live games pinned.
struct GamesScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelectGame: (Int) -> Void

    @State private var model: GamesViewModel

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelectGame: @escaping (Int) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelectGame = onSelectGame
        _model = State(initialValue: GamesViewModel(api: appModel.api))
    }

    var body: some View {
        @Bindable var model = model
        let favorite = favorites.resolve(in: appModel.clubs)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Games", selection: $model.mode) {
                    Text("Upcoming").tag(GamesList.Mode.upcoming)
                    Text("Results").tag(GamesList.Mode.results)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("games.mode")

                if let favorite {
                    ChipBar(options: [(false, String(localized: "All clubs")), (true, favorite.displayName)], selection: $model.onlyMyClub)
                        .padding(.horizontal, -16)
                        .accessibilityIdentifier("games.filter")
                }

                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                case .failed:
                    LoadFailedView { Task { await model.load(season: appModel.season) } }
                case .loaded:
                    if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
                    list(model.sections(favoriteId: favorite?.id))
                }
            }
            .padding()
        }
        .background(Theme.ink)
        .navigationTitle("Games")
        .refreshable { await model.load(season: appModel.season) }
        .task { if model.state == .idle { await model.load(season: appModel.season) } }
    }

    @ViewBuilder
    private func list(_ sections: GamesList.Sections) -> some View {
        if !sections.live.isEmpty {
            day(title: Text("Live now").foregroundStyle(Theme.live), games: sections.live, id: "live")
        }
        ForEach(sections.days) { day in
            self.day(title: Text(verbatim: Format.dayHeader(day.date, now: .now)).foregroundStyle(Theme.textSecondary),
                     games: day.games, id: "\(Int(day.date.timeIntervalSince1970))")
        }
        if sections.live.isEmpty && sections.days.isEmpty {
            Text(model.mode == .upcoming ? "No upcoming games in the published schedule yet." : "No results yet.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 120)
                .accessibilityIdentifier("games.empty")
        }
    }

    private func day(title: Text, games: [Game], id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            title
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            ForEach(games) { game in
                Button { onSelectGame(game.id) } label: {
                    GameRow(game: game, home: club(game.home.team), away: club(game.away.team), favoriteClubId: favorites.clubId)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("games.row.\(game.id)")
            }
        }
    }

    private func club(_ team: Team) -> Club {
        appModel.club(id: team.id) ?? Club(team: team, settings: appModel.config?.teams[team.id])
    }
}
