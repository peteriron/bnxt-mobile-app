import SwiftUI

/// The club page (§3.8): a hero in the club colour, facts, Make my club, Tickets, and
/// Roster · Games · Player stats.
struct ClubScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void

    @State private var model: ClubViewModel

    init(clubId: Int, appModel: AppModel, favorites: FavoriteClubStore, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelect = onSelect
        _model = State(initialValue: ClubViewModel(clubId: clubId, api: appModel.api))
    }

    private var club: Club? {
        appModel.club(id: model.clubId) ?? model.team.map { Club(team: $0, settings: appModel.config?.teams[$0.id]) }
    }

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ClubHero(club: club, id: model.clubId, arena: model.arena, standing: model.standing, statistics: model.team?.statistics,
                         isFavorite: favorites.clubId == model.clubId) {
                    if let club { favorites.choose(club) }
                }

                if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }

                Picker("Section", selection: $model.tab) {
                    Text("Roster").tag(ClubViewModel.Tab.roster)
                    Text("Games").tag(ClubViewModel.Tab.games)
                    Text("Player stats").tag(ClubViewModel.Tab.stats)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("club.tabs")

                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                case .failed:
                    LoadFailedView { Task { await model.load(season: appModel.season) } }
                case .loaded:
                    switch model.tab {
                    case .roster: RosterList(rows: model.rosterRows, onSelect: onSelect)
                    case .games: ClubGamesList(model: model, appModel: appModel, favoriteId: favorites.clubId, onSelect: onSelect)
                    case .stats: PlayerStatsTable(model: model, onSelect: onSelect)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(alignment: .top) {
            LinearGradient(colors: [(club?.graphicColor ?? .violet).color.opacity(0.55), Theme.ink], startPoint: .top, endPoint: .bottom)
                .frame(height: 420)
                .ignoresSafeArea()
        }
        .background(Theme.ink)
        .navigationTitle(Text(verbatim: club?.displayName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(season: appModel.season) }
        .task { if model.state == .idle { await model.load(season: appModel.season) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.club.\(model.clubId)")
    }
}

// MARK: - Hero

private struct ClubHero: View {
    let club: Club?
    let id: Int
    let arena: String?
    let standing: Standing?
    let statistics: TeamStatistics?
    let isFavorite: Bool
    let makeFavorite: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptiveStack(verticalAlignment: .center, spacing: 14) {
                ClubLogo(club: club, size: 76)
                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: club?.displayName ?? "")
                        .font(Theme.display(.title2))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                    let place = [club?.country?.flag, club?.city, arena].compactMap { $0 }.joined(separator: " · ")
                    if !place.isEmpty {
                        Text(verbatim: place).font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    if let official = club?.officialName, official != club?.displayName {
                        Text(verbatim: official).font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .overlay(alignment: .trailing) { watermark }

            let facts: [(String?, LocalizedStringKey)] = [
                (standing.map { "\($0.wins)–\($0.losses)" }, "Record"), (standing.map { Format.ordinal($0.position) }, "League"),
                (statistics.map { Format.average($0.pointsFor) }, "PPG"), (statistics.map { Format.average($0.pointsAgainst) }, "Opp PPG")
            ]
            TileRows(count: facts.count, perRow: dynamicTypeSize.isAccessibilitySize ? 2 : 4) { fact(facts[$0].0, facts[$0].1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("club.facts")

            AdaptiveStack(spacing: 10) {
                if isFavorite {
                    Label("My club", systemImage: "star.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.lime)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Theme.lime.opacity(0.14), in: Capsule())
                        .accessibilityIdentifier("club.isMyClub")
                } else {
                    Button(action: makeFavorite) {
                        Label("Make my club", systemImage: "star").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.textPrimary)
                    .disabled(club == nil)
                    .accessibilityIdentifier("club.makeMyClub")
                }

                if let url = club?.ticketURL {
                    Link(destination: url) {
                        Label("Tickets", systemImage: "ticket").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.violet)
                    .accessibilityIdentifier("club.tickets")
                }
            }
            .controlSize(.large)
        }
        .padding(.top, 8)
    }

    @ViewBuilder private var watermark: some View {
        if let club {
            ClubLogo(club: club, size: 150)
                .opacity(0.08)
                .offset(x: 30)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func fact(_ value: String?, _ title: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value ?? "–")
                .font(Theme.score(.title3))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title).font(.caption2.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface.opacity(0.8), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Roster

private struct RosterList: View {
    let rows: [ClubPage.RosterRow]
    let onSelect: (Route) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if rows.isEmpty {
                Text("No roster published yet.").font(.subheadline).foregroundStyle(Theme.textSecondary).padding()
            }
            ForEach(rows) { row in
                Button { onSelect(.player(rosterId: row.entry.id)) } label: { RosterRowView(row: row) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("club.roster.\(row.entry.id)")
                if row.id != rows.last?.id { Divider().overlay(Theme.surface3).padding(.leading, 96) }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.roster")
    }
}

private struct RosterRowView: View {
    let row: ClubPage.RosterRow

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let player = row.entry.player
        let large = dynamicTypeSize.isAccessibilitySize
        HStack(spacing: 12) {
            Text(verbatim: row.jersey ?? "")
                .font(Theme.score(.subheadline))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize()
                .frame(minWidth: 28, alignment: .trailing)
            if !large { PlayerAvatar(player: player, size: 42) }
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: player.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .oneLineUnlessAccessibilitySize()
                Text(verbatim: details)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .oneLineUnlessAccessibilitySize()
                if large, let points = row.pointsPerGame {
                    Text(verbatim: "\(Format.average(points)) PTS").font(Theme.score(.callout)).foregroundStyle(Theme.textPrimary)
                }
            }
            Spacer(minLength: 4)
            if !large, let points = row.pointsPerGame {
                VStack(spacing: 0) {
                    Text(verbatim: Format.average(points)).font(Theme.score(.callout)).foregroundStyle(Theme.textPrimary)
                    Text(verbatim: "PTS").font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                }
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [row.jersey.map { "#\($0)" }, player.fullName].compactMap { $0 }.joined(separator: " ")))
        .accessibilityValue(Text(verbatim: [details, row.pointsPerGame.map { String(localized: "\(Format.average($0)) points per game") }]
            .compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }

    private var details: String {
        var parts: [String] = [row.entry.position?.abbreviation ?? String(localized: "Position n/a")]
        if let height = row.entry.heightCm { parts.append("\(height) cm") }
        if let code = row.entry.player.nationalityCode {
            parts.append([Nationality.flag(ioc: code), Nationality.name(ioc: code)].compactMap { $0 }.joined(separator: " "))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Games

private struct ClubGamesList: View {
    let model: ClubViewModel
    let appModel: AppModel
    let favoriteId: Int?
    let onSelect: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Upcoming")
                if model.upcoming.isEmpty {
                    Text("No games scheduled").font(.subheadline).foregroundStyle(Theme.textSecondary).padding(.horizontal, 4)
                }
                rows(model.upcoming)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Results")
                    if !model.form.isEmpty { FormStrip(wins: model.form) }
                }
                if model.results.isEmpty {
                    Text("No results yet").font(.subheadline).foregroundStyle(Theme.textSecondary).padding(.horizontal, 4)
                }
                rows(model.results)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("club.games")
    }

    private func rows(_ games: [Game]) -> some View {
        VStack(spacing: 8) {
            ForEach(games) { game in
                Button { onSelect(.game(id: game.id)) } label: {
                    GameRow(game: game, home: club(game.home.team), away: club(game.away.team), favoriteClubId: favoriteId,
                            subtitle: Format.relativeDay(game.tipOff, now: .now))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("club.game.\(game.id)")
            }
        }
    }

    private func club(_ team: Team) -> Club {
        appModel.club(id: team.id) ?? Club(team: team, settings: appModel.config?.teams[team.id])
    }
}
