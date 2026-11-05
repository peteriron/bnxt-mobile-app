import SwiftUI

/// Search (§3.8): clubs and players from the first character; my club and the league's VAL leaders as suggestions
/// while the field is empty.
struct SearchScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void

    @State private var model: SearchViewModel
    @FocusState private var focused: Bool

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelect = onSelect
        _model = State(initialValue: SearchViewModel(api: appModel.api))
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                if model.isSearching { results } else { suggestions }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Theme.ink)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Players and clubs"))
        .searchFocused($focused)
        .onAppear { focused = true }
        .task { if model.state == .idle { await model.load(season: appModel.season, teamIds: appModel.clubs.map(\.id)) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.search")
    }

    private func club(_ id: Int) -> Club? { appModel.club(id: id) }

    // MARK: Results

    @ViewBuilder private var results: some View {
        let clubs = model.clubResults(appModel.clubs)
        let players = model.playerResults
        if !clubs.isEmpty {
            group("Clubs", id: "search.clubs") {
                ForEach(clubs) { club in
                    row(id: "search.club.\(club.shortName)", route: .club(id: club.id)) {
                        ClubLogo(club: club, size: 34)
                    } title: {
                        club.displayName
                    } subtitle: {
                        [club.country?.flag, club.city].compactMap { $0 }.joined(separator: " ")
                    }
                }
            }
        }
        if !players.isEmpty {
            group("Players", id: "search.players") {
                ForEach(players) { player in
                    row(id: "search.player.\(player.rosterId)", route: .player(rosterId: player.rosterId)) {
                        PlayerAvatar(player: player.player, size: 38)
                    } title: {
                        player.player.fullName
                    } subtitle: {
                        [club(player.teamId)?.displayName, player.position?.abbreviation].compactMap { $0 }.joined(separator: " · ")
                    }
                }
            }
        }
        if clubs.isEmpty && players.isEmpty {
            if model.state == .loading {
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ContentUnavailableView {
                    Label("No results", systemImage: "magnifyingglass")
                } description: {
                    Text("Nothing matches “\(model.query)”. Try a surname or a city.")
                }
                .accessibilityIdentifier("search.empty")
            }
        }
        if model.playersUnavailable {
            Text("Players can't be searched until the rosters load. Check your connection.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
                .accessibilityIdentifier("search.playersUnavailable")
        }
    }

    // MARK: Suggestions

    @ViewBuilder private var suggestions: some View {
        if let mine = favorites.resolve(in: appModel.clubs) {
            group("My club", id: "search.suggestions.club") {
                row(id: "search.suggestion.club", route: .club(id: mine.id)) {
                    ClubLogo(club: mine, size: 34)
                } title: {
                    mine.displayName
                } subtitle: {
                    [mine.country?.flag, mine.city].compactMap { $0 }.joined(separator: " ")
                }
            }
        }
        let leaders = model.suggestedPlayers
        if !leaders.isEmpty {
            group("League leaders", id: "search.suggestions.players") {
                ForEach(leaders, id: \.rosterId) { entry in
                    row(id: "search.suggestion.\(entry.rosterId)", route: .player(rosterId: entry.rosterId)) {
                        PlayerAvatar(player: entry.player, size: 38)
                    } title: {
                        entry.player.fullName
                    } subtitle: {
                        "\(club(entry.team.id)?.displayName ?? entry.team.name) · \(Format.average(entry.value)) VAL"
                    }
                }
            }
        }
        Text("Search by player, club or city.")
            .font(.footnote)
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 4)
    }

    // MARK: Building blocks

    private func group(_ title: LocalizedStringKey, id: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { rows() }
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(id)
    }

    private func row(id: String, route: Route, @ViewBuilder leading: () -> some View,
                     title: () -> String, subtitle: () -> String) -> some View {
        let title = title(), subtitle = subtitle()
        return Button { onSelect(route) } label: {
            HStack(spacing: 12) {
                leading()
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    if !subtitle.isEmpty {
                        Text(verbatim: subtitle).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: title))
        .accessibilityValue(Text(verbatim: subtitle))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(id)
    }
}
