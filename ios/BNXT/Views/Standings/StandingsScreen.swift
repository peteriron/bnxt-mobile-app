import SwiftUI

/// The Standings tab (§3.5): League / Belgium / Netherlands tables with config zones and a cut line,
/// projected playoff brackets, a legend and the season explainer.
struct StandingsScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelectClub: (Int) -> Void

    @State private var model: StandingsViewModel

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelectClub: @escaping (Int) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelectClub = onSelectClub
        _model = State(initialValue: StandingsViewModel(api: appModel.api))
    }

    var body: some View {
        @Bindable var model = model
        let table = model.table(config: appModel.config, clubs: appModel.clubs)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("View", selection: $model.segment) {
                    Text("League").tag(StandingsViewModel.Segment.league)
                    Text("Belgium").tag(StandingsViewModel.Segment.belgium)
                    Text("Netherlands").tag(StandingsViewModel.Segment.netherlands)
                    if appModel.config?.playoffs != nil {
                        Text("Playoffs").tag(StandingsViewModel.Segment.playoffs)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("standings.segment")

                content(table: table)

                explainer
            }
            .padding()
        }
        .background(Theme.ink)
        .navigationTitle("Standings")
        .refreshable { await model.load(season: appModel.season) }
        .task { if model.state == .idle { await model.load(season: appModel.season) } }
    }

    @ViewBuilder
    private func content(table: StandingsTable) -> some View {
        switch model.state {
        case .idle, .loading:
            ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        case .failed:
            LoadFailedView { Task { await model.load(season: appModel.season) } }
        case .loaded:
            Text(verbatim: subtitle(table: table))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 4)
            if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
            if let scope = model.segment.scope {
                StandingsTableView(rows: table.rows(for: scope), scope: scope, cutLine: table.cutLine(for: scope),
                                   appModel: appModel, favoriteId: favorites.clubId, onSelect: onSelectClub)
                StandingsLegend(zones: table.legendZones(for: scope), relegation: appModel.config?.relegation ?? false)
            } else if let playoffs = appModel.config?.playoffs {
                ForEach(playoffs.brackets, id: \.country) { bracket in
                    BracketView(bracket: ProjectedBracket(bracket: bracket, table: table), appModel: appModel,
                                favoriteId: favorites.clubId, onSelect: onSelectClub)
                }
                Text("This is how the brackets would look if the regular season ended today. The higher seed has home-court advantage.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private func subtitle(table: StandingsTable) -> String {
        let season = appModel.season
        return String(localized: "Regular season \(season.label) · after \(table.gamesPlayed) of \(season.gamesPerTeam) games")
    }

    @ViewBuilder private var explainer: some View {
        let paragraphs = appModel.config?.seasonExplainer(for: "en") ?? []
        if !paragraphs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("How the season works")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(paragraphs, id: \.self) { paragraph in
                    Text(verbatim: paragraph).font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("standings.explainer")
        }
    }
}

// MARK: - Table

private struct StandingsTableView: View {
    let rows: [StandingsTable.Row]
    let scope: StandingsScope
    let cutLine: Int?
    let appModel: AppModel
    let favoriteId: Int?
    let onSelect: (Int) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            if !dynamicTypeSize.isAccessibilitySize { header } // the rows spell their numbers out instead
            ForEach(rows) { row in
                if let cutLine, row.rank == cutLine + 1 {
                    CutLine()
                }
                Button { onSelect(row.standing.team.id) } label: { RowView(row: row, scope: scope, club: club(for: row), isFavorite: row.id == favoriteId) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("standings.row.\(row.standing.team.shortName)")
            }
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("standings.table")
    }

    private func club(for row: StandingsTable.Row) -> Club {
        appModel.club(id: row.standing.team.id)
            ?? Club(team: row.standing.team, settings: appModel.config?.teams[row.standing.team.id])
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text(verbatim: "").frame(width: StandingsLayout.rank)
            Text("Club").frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: "W").frame(width: StandingsLayout.number, alignment: .trailing)
            Text(verbatim: "L").frame(width: StandingsLayout.number, alignment: .trailing)
            Text(verbatim: "+/-").frame(width: StandingsLayout.difference, alignment: .trailing)
            Text("Strk").frame(width: StandingsLayout.streak, alignment: .trailing)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Theme.textTertiary)
        .padding(.trailing, 14)
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

private enum StandingsLayout {
    static let rank: CGFloat = 40
    static let number: CGFloat = 28
    static let difference: CGFloat = 44
    static let streak: CGFloat = 40
}

private struct RowView: View {
    let row: StandingsTable.Row
    let scope: StandingsScope
    let club: Club
    let isFavorite: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize { stacked } else { columns }
        }
        .frame(minHeight: 44)
        .background(isFavorite ? Theme.lime.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.rank). \(club.displayName)"))
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
    }

    private var zoneBar: some View {
        Rectangle()
            .fill(row.zone.flatMap { RGB(hexString: $0.color) }?.color ?? .clear)
            .frame(width: 3)
    }

    /// Accessibility sizes: the club on one line, its numbers spelled out on the next, so no column breaks digits apart.
    private var stacked: some View {
        let standing = row.standing
        return HStack(alignment: .top, spacing: 10) {
            zoneBar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(verbatim: "\(row.rank)").font(Theme.compactNumber(.subheadline)).foregroundStyle(Theme.textPrimary)
                    Text(verbatim: club.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                }
                Text(verbatim: ["\(standing.wins)–\(standing.losses)", Format.plusMinus(Double(standing.pointDifference)),
                                standing.streak.map(Format.streak)].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.trailing, 14)
    }

    private var columns: some View {
        let standing = row.standing
        return HStack(spacing: 0) {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(row.zone.flatMap { RGB(hexString: $0.color) }?.color ?? .clear)
                    .frame(width: 3)
                Text(verbatim: "\(row.rank)")
                    .font(Theme.compactNumber(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: StandingsLayout.rank)

            HStack(spacing: 8) {
                ClubLogo(club: club, size: 24)
                Text(verbatim: club.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if scope == .league, let country = club.country {
                    Text(verbatim: country.flag).font(.caption).accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Group {
                Text(verbatim: "\(standing.wins)").frame(width: StandingsLayout.number, alignment: .trailing)
                    .foregroundStyle(Theme.textPrimary).fontWeight(.bold)
                Text(verbatim: "\(standing.losses)").frame(width: StandingsLayout.number, alignment: .trailing)
                Text(verbatim: Format.plusMinus(Double(standing.pointDifference))).frame(width: StandingsLayout.difference, alignment: .trailing)
                Text(verbatim: standing.streak.map(Format.streak) ?? "–")
                    .frame(width: StandingsLayout.streak, alignment: .trailing)
                    .foregroundStyle(standing.streak.map { $0.isWinning ? Theme.win : Theme.loss } ?? Theme.textTertiary)
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.trailing, 14)
    }

    private var accessibilityValue: Text {
        let standing = row.standing
        var parts = [String(localized: "\(standing.wins) wins, \(standing.losses) losses")]
        parts.append(String(localized: "point difference \(Format.plusMinus(Double(standing.pointDifference)))"))
        if let streak = standing.streak { parts.append(Format.streakDescription(streak)) }
        if let zone = row.zone { parts.append(zone.label) }
        if isFavorite { parts.append(String(localized: "My club")) }
        return Text(verbatim: parts.joined(separator: ", "))
    }
}

/// The dashed line after the last playoff place.
private struct CutLine: View {
    var body: some View {
        Line()
            .stroke(Theme.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            .frame(height: 1.5)
            .padding(.horizontal, 10)
            .accessibilityElement()
            .accessibilityLabel("Playoff cut line")
            .accessibilityIdentifier("standings.cutLine")
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
        }
    }
}

private struct StandingsLegend: View {
    let zones: [RemoteConfig.StandingsZone]
    let relegation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(zones, id: \.id) { zone in
                item(color: RGB(hexString: zone.color)?.color ?? Theme.surface3, text: Text(verbatim: zone.label))
            }
            if !relegation {
                item(color: Theme.surface3, text: Text("No relegation this season"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("standings.legend")
    }

    private func item(color: Color, text: Text) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12).accessibilityHidden(true)
            text.font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }
}

// MARK: - Playoffs

private struct BracketView: View {
    let bracket: ProjectedBracket
    let appModel: AppModel
    let favoriteId: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(verbatim: "\(bracket.country.flag) \(bracket.label)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("Projected")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(Theme.lime)
                    .background(Theme.lime.opacity(0.14), in: Capsule())
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 14) {
                    ForEach(Array(bracket.rounds.enumerated()), id: \.offset) { _, round in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(verbatim: "\(round.label) · Bo\(round.bestOf)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.textTertiary)
                                .accessibilityLabel(Text("\(round.label), best of \(round.bestOf)"))
                            ForEach(0..<round.matchupCount, id: \.self) { index in
                                MatchupView(matchup: round.matchups[safe: index], appModel: appModel, favoriteId: favoriteId, onSelect: onSelect)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("standings.bracket.\(bracket.country.rawValue)")
    }
}

private struct MatchupView: View {
    let matchup: ProjectedBracket.Matchup?
    let appModel: AppModel
    let favoriteId: Int?
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            slot(matchup?.higher)
            Divider().overlay(Theme.surface3)
            slot(matchup?.lower)
        }
        .frame(width: 180)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func slot(_ seed: ProjectedBracket.Seed?) -> some View {
        if let seed, let standing = seed.standing {
            let club = appModel.club(id: standing.team.id) ?? Club(team: standing.team, settings: appModel.config?.teams[standing.team.id])
            Button { onSelect(standing.team.id) } label: {
                HStack(spacing: 8) {
                    Text(verbatim: "\(seed.seed)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 14)
                    ClubLogo(club: club, size: 20)
                    Text(verbatim: club.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text(verbatim: "\(standing.wins)–\(standing.losses)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 10)
                .frame(height: 38)
                .background(standing.team.id == favoriteId ? Theme.lime.opacity(0.08) : .clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Seed \(seed.seed), \(club.displayName), \(standing.wins)–\(standing.losses)"))
            .accessibilityAddTraits(.isButton)
        } else {
            Text("To be decided")
                .font(.subheadline)
                .foregroundStyle(Theme.textTertiary)
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .padding(.horizontal, 10)
        }
    }
}
