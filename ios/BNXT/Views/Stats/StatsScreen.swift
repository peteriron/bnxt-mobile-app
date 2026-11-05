import SwiftUI

/// The Stats tab (§3.6): league leaders per category with a hero card for #1, or clubs ranked by team stats.
/// The toolbar's Compare button opens §3.7.
struct StatsScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void

    @State private var model: StatsViewModel

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelect = onSelect
        _model = State(initialValue: StatsViewModel(api: appModel.api))
    }

    private var teamIds: [Int] { appModel.clubs.map(\.id) }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("View", selection: $model.mode) {
                    Text("Players").tag(StatsViewModel.Mode.players)
                    Text("Teams").tag(StatsViewModel.Mode.teams)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .accessibilityIdentifier("stats.segment")

                switch model.mode {
                case .players:
                    ChipBar(options: LeaderCategory.allCases.map { ($0, $0.chipTitle) }, selection: $model.playerCategory) {
                        "stats.category.\($0.rawValue)"
                    }
                case .teams:
                    ChipBar(options: TeamStatCategory.allCases.map { ($0, $0.chipTitle) }, selection: $model.teamCategory) {
                        "stats.teamCategory.\($0.rawValue)"
                    }
                }

                content.padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Theme.ink)
        .navigationTitle("Stats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { onSelect(.compare(rosterId: nil)) } label: { Image(systemName: "person.2.fill") }
                    .accessibilityLabel("Compare players")
                    .accessibilityIdentifier("stats.compare")
            }
        }
        .refreshable { await model.refresh(season: appModel.season, teamIds: teamIds) }
        .task(id: model.mode) { await model.loadIfNeeded(season: appModel.season, teamIds: teamIds) }
    }

    @ViewBuilder private var content: some View {
        switch model.state {
        case .idle, .loading:
            VStack(spacing: 10) {
                ProgressView()
                if model.mode == .players {
                    Text("Loading the league leaders…").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        case .failed:
            LoadFailedView { Task { await model.refresh(season: appModel.season, teamIds: teamIds) } }
        case .loaded:
            if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
            switch model.mode {
            case .players: players
            case .teams: teams
            }
        }
    }

    // MARK: Players

    @ViewBuilder private var players: some View {
        let rows = model.playerRows
        let category = model.playerCategory
        if let first = rows.first {
            LeaderHero(row: first, category: category, club: club(for: first.entry.team)) {
                onSelect(.player(rosterId: first.entry.rosterId))
            }
            VStack(spacing: 0) {
                ForEach(rows.dropFirst()) { row in
                    Button { onSelect(.player(rosterId: row.entry.rosterId)) } label: {
                        LeaderRow(row: row, category: category, club: club(for: row.entry.team))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats.player.\(row.entry.rosterId)")
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats.players")
            Text("Per-game averages, regular season \(appModel.season.label). VAL is FIBA efficiency. Percentages need minimum attempts.")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 4)
        } else {
            ContentUnavailableView("No rankings yet", systemImage: "chart.bar",
                                   description: Text("The league publishes rankings once games have been played."))
        }
    }

    // MARK: Teams

    @ViewBuilder private var teams: some View {
        let rows = model.teamRows
        let category = model.teamCategory
        Text(verbatim: category.explanation)
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 4)
        if rows.isEmpty {
            ContentUnavailableView("No team stats yet", systemImage: "chart.bar",
                                   description: Text("Team stats appear once games have been played."))
        } else {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    let club = appModel.club(id: row.teamId)
                    Button { onSelect(.club(id: row.teamId)) } label: {
                        TeamStatRow(row: row, category: category, club: club, isFavorite: row.teamId == favorites.clubId)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats.team.\(club?.shortName ?? "\(row.teamId)")")
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("stats.teams")
            Text("Computed from the box scores of finished games, regular season \(appModel.season.label).")
                .font(.footnote)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    /// Leader entries carry no country; the app's clubs fill it in.
    private func club(for team: Team) -> Club {
        appModel.club(id: team.id) ?? Club(team: team, settings: appModel.config?.teams[team.id])
    }
}

// MARK: - Category names

extension LeaderCategory {
    var chipTitle: String {
        switch self {
        case .efficiency: "VAL"
        case .points: "PTS"
        case .rebounds: "REB"
        case .assists: "AST"
        case .steals: "STL"
        case .blocks: "BLK"
        case .twoPointPercentage: "2P%"
        case .threePointPercentage: "3P%"
        case .freeThrowPercentage: "FT%"
        }
    }

    var title: String {
        switch self {
        case .efficiency: String(localized: "Efficiency")
        case .points: String(localized: "Points")
        case .rebounds: String(localized: "Rebounds")
        case .assists: String(localized: "Assists")
        case .steals: String(localized: "Steals")
        case .blocks: String(localized: "Blocks")
        case .twoPointPercentage: String(localized: "2-point %")
        case .threePointPercentage: String(localized: "3-point %")
        case .freeThrowPercentage: String(localized: "Free throw %")
        }
    }

    func formatted(_ value: Double) -> String {
        isPercentage ? Format.average(value) + "%" : Format.average(value)
    }
}

extension TeamStatCategory {
    var chipTitle: String {
        switch self {
        case .points: String(localized: "Points")
        case .pointsAllowed: String(localized: "Defense")
        case .rebounds: String(localized: "Rebounds")
        case .assists: String(localized: "Assists")
        case .fieldGoalPercentage: "FG%"
        case .threePointPercentage: "3P%"
        case .steals: String(localized: "Steals")
        case .turnovers: String(localized: "Turnovers")
        }
    }

    var explanation: String {
        switch self {
        case .points: String(localized: "Points scored per game")
        case .pointsAllowed: String(localized: "Points allowed per game (lower is better)")
        case .rebounds: String(localized: "Rebounds per game")
        case .assists: String(localized: "Assists per game")
        case .fieldGoalPercentage: String(localized: "Field goal percentage")
        case .threePointPercentage: String(localized: "3-point percentage")
        case .steals: String(localized: "Steals per game")
        case .turnovers: String(localized: "Turnovers per game (lower is better)")
        }
    }

    func formatted(_ value: Double) -> String {
        isPercentage ? Format.average(value) + "%" : Format.average(value)
    }
}

// MARK: - Rows

/// #1 in the category: photo, value and club on the club's colour.
private struct LeaderHero: View {
    let row: StatsBoard.PlayerRow
    let category: LeaderCategory
    let club: Club
    let action: () -> Void

    var body: some View {
        let player = row.entry.player
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [club.graphicColor.color.opacity(0.6), Theme.surface], startPoint: .topTrailing, endPoint: .bottomLeading)
                if let url = player.photo?.medium ?? player.photo?.url {
                    AsyncImage(url: url) { phase in
                        if case let .success(image) = phase { image.resizable().scaledToFit() } else { Color.clear }
                    }
                    .frame(width: 150, height: 180, alignment: .bottom)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)
                } else {
                    PlayerAvatar(player: player, size: 96)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(20)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(category.title) leader")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(verbatim: category.formatted(row.entry.value))
                        .font(Theme.score(.largeTitle))
                        .foregroundStyle(Theme.textPrimary)
                    Text(verbatim: player.fullName)
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        ClubLogo(club: club, size: 16)
                        Text(verbatim: club.displayName).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(maxWidth: 200, alignment: .leading)
                .padding(16)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(category.title) leader: \(player.fullName), \(club.displayName)"))
        .accessibilityValue(Text(verbatim: category.formatted(row.entry.value)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("stats.leader")
    }
}

private struct LeaderRow: View {
    let row: StatsBoard.PlayerRow
    let category: LeaderCategory
    let club: Club

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(row.rank)")
                .font(Theme.compactNumber(.subheadline))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 24)
            PlayerAvatar(player: row.entry.player, size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: row.entry.player.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(verbatim: club.displayName).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                Meter(fraction: row.fraction, color: club.graphicColor)
            }
            Text(verbatim: category.formatted(row.entry.value))
                .font(Theme.compactNumber(.body))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.rank). \(row.entry.player.fullName), \(club.displayName)"))
        .accessibilityValue(Text(verbatim: category.formatted(row.entry.value)))
        .accessibilityAddTraits(.isButton)
    }
}

private struct TeamStatRow: View {
    let row: StatsBoard.TeamRow
    let category: TeamStatCategory
    let club: Club?
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(row.rank)")
                .font(Theme.compactNumber(.subheadline))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 24)
            ClubLogo(club: club, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: club?.displayName ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Meter(fraction: row.fraction, color: club?.graphicColor ?? .violet)
            }
            Text(verbatim: category.formatted(row.value))
                .font(Theme.compactNumber(.body))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(isFavorite ? Theme.lime.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.rank). \(club?.displayName ?? "")"))
        .accessibilityValue(Text(verbatim: [category.formatted(row.value), isFavorite ? String(localized: "My club") : nil]
            .compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }
}

/// A thin horizontal bar, 0...1 of the available width, in a (lifted) club colour.
struct Meter: View {
    let fraction: Double
    let color: RGB

    var body: some View {
        Capsule()
            .fill(Theme.surface3)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule().fill(color.lifted().color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .accessibilityHidden(true)
    }
}
