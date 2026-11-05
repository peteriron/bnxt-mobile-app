import SwiftUI

/// The player page (§3.8): cut-out photo hero with a jersey watermark, bio, season averages with league ranks,
/// shooting rings, points per game and the game log. Players without games show the bio only.
struct PlayerScreen: View {
    let appModel: AppModel
    let onSelect: (Route) -> Void

    @State private var model: PlayerViewModel

    init(rosterId: Int, appModel: AppModel, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.onSelect = onSelect
        _model = State(initialValue: PlayerViewModel(rosterId: rosterId, api: appModel.api))
    }

    private var club: Club? { appModel.club(id: model.teamId) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case .failed:
                    LoadFailedView { Task { await model.load(season: appModel.season) } }
                case .loaded:
                    if let player = model.entry?.player {
                        PlayerHero(player: player, jersey: model.jersey, club: club) {
                            if let id = model.teamId { onSelect(.club(id: id)) }
                        }
                    }
                    if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
                    PlayerBio(entry: model.entry, age: model.age)
                    if let season = model.season {
                        SeasonAverages(season: season, rank: model.rank)
                        ShootingRings(season: season, color: club?.graphicColor ?? .violet)
                        pointsChart(season: season)
                        GameLog(rows: model.log, appModel: appModel, onSelect: onSelect)
                        compareButton
                    } else {
                        Text("No games played yet this season.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .accessibilityIdentifier("player.noGames")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(alignment: .top) {
            LinearGradient(colors: [(club?.graphicColor ?? .violet).color.opacity(0.5), Theme.ink], startPoint: .top, endPoint: .bottom)
                .frame(height: 380)
                .ignoresSafeArea()
        }
        .background(Theme.ink)
        .navigationTitle(Text(verbatim: model.entry?.player.fullName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(season: appModel.season) }
        .task { if model.state == .idle { await model.load(season: appModel.season) } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.player.\(model.rosterId)")
    }

    /// §3.7: opens Compare with this player in slot A.
    private var compareButton: some View {
        Button { onSelect(.compare(rosterId: model.rosterId)) } label: {
            Label("Compare with another player", systemImage: "person.2.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(Theme.textPrimary)
                .background(Theme.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("player.compare")
    }

    private func pointsChart(season: PlayerPage.SeasonStats) -> some View {
        let chart = PlayerPage.pointsChart(model.lines)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Points per game")
            Sparkline(values: chart.values, labels: chart.labels, average: season.perGame.points, color: club?.graphicColor ?? .violet)
                .padding(14)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityIdentifier("player.chart")
    }
}

// MARK: - Hero and bio

private struct PlayerHero: View {
    let player: Player
    let jersey: String?
    let club: Club?
    let openClub: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let jersey {
                Text(verbatim: jersey)
                    .font(Theme.score(.largeTitle))
                    .scaleEffect(4.5, anchor: .topTrailing)
                    .foregroundStyle((club?.graphicColor ?? .violet).color.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.trailing, 40)
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }
            photo
                .frame(maxWidth: .infinity, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: player.firstName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text(verbatim: player.lastName.uppercased())
                    .font(Theme.display(.title))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                if let club {
                    Button(action: openClub) {
                        HStack(spacing: 6) {
                            ClubLogo(club: club, size: 22)
                            Text(verbatim: club.displayName).font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                    .accessibilityIdentifier("player.club")
                }
            }
            .frame(maxWidth: 220, alignment: .leading)
            .padding(.bottom, 12)
            .accessibilityElement(children: .contain)
        }
        .frame(height: 280)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: [player.fullName, jersey.map { "#\($0)" }].compactMap { $0 }.joined(separator: ", ")))
    }

    @ViewBuilder private var photo: some View {
        if let url = player.photo?.medium ?? player.photo?.url {
            AsyncImage(url: url) { phase in
                if case let .success(image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: 220, height: 280, alignment: .bottom)
            .accessibilityHidden(true)
        } else {
            PlayerAvatar(player: player, size: 140).padding(.bottom, 40).padding(.trailing, 20)
        }
    }
}

private struct PlayerBio: View {
    let entry: RosterEntry?
    let age: Int?

    var body: some View {
        HStack(spacing: 8) {
            item(entry?.position?.abbreviation, "Position")
            item(entry?.heightCm.map { "\($0) cm" }, "Height")
            item(age.map { "\($0)" }, "Age")
            item(entry?.player.nationalityCode.map { [Nationality.flag(ioc: $0), $0].compactMap { $0 }.joined(separator: " ") }, "Nationality",
                 accessibilityValue: entry?.player.nationalityCode.map { Nationality.name(ioc: $0) })
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.bio")
    }

    private func item(_ value: String?, _ title: LocalizedStringKey, accessibilityValue: String? = nil) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value ?? "–")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title).font(.caption2.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text(verbatim: accessibilityValue ?? value ?? String(localized: "Unknown")))
    }
}

// MARK: - Averages and shooting

private struct SeasonAverages: View {
    let season: PlayerPage.SeasonStats
    let rank: (LeaderCategory) -> Int?

    private struct Item: Identifiable {
        let id: String
        let value: Double
        let category: LeaderCategory?
    }

    var body: some View {
        let line = season.perGame
        let main = [Item(id: "PTS", value: line.points, category: .points), Item(id: "REB", value: line.rebounds, category: .rebounds),
                    Item(id: "AST", value: line.assists, category: .assists), Item(id: "VAL", value: line.efficiency, category: .efficiency)]
        let more = [Item(id: "STL", value: line.steals, category: .steals), Item(id: "BLK", value: line.blocks, category: .blocks),
                    Item(id: "TO", value: line.turnovers, category: nil), Item(id: "PF", value: line.fouls, category: nil)]
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Season averages")
            Text("\(season.games) games").font(.footnote).foregroundStyle(Theme.textSecondary).padding(.horizontal, 4)
            VStack(spacing: 8) {
                HStack(spacing: 8) { ForEach(main) { tile($0, large: true) } }
                HStack(spacing: 8) { ForEach(more) { tile($0, large: false) } }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.averages")
    }

    private func tile(_ item: Item, large: Bool) -> some View {
        let rank = item.category.flatMap(rank)
        return VStack(spacing: 3) {
            Text(verbatim: Format.average(item.value))
                .font(large ? Theme.score(.title3) : Theme.score(.callout))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(verbatim: item.id).font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
            if let rank {
                Text("#\(rank) in league")
                    .font(.system(size: 9, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.lime, in: Capsule())
                    .accessibilityIdentifier("player.rank.\(item.id)")
            }
        }
        .frame(maxWidth: .infinity, minHeight: large ? 76 : 58)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: item.id))
        .accessibilityValue(Text(verbatim: [Format.average(item.value), rank.map { String(localized: "number \($0) in the league") }]
            .compactMap { $0 }.joined(separator: ", ")))
    }
}

private struct ShootingRings: View {
    let season: PlayerPage.SeasonStats
    let color: RGB

    var body: some View {
        let totals = season.totals, perGame = season.perGame
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Shooting")
            HStack {
                StatRing(title: "FG", percentage: totals.fieldGoalPercentage,
                         detail: Self.detail(perGame.fieldGoalsMade, perGame.fieldGoalsAttempted), color: color)
                StatRing(title: "2PT", percentage: totals.twoPointPercentage,
                         detail: Self.detail(perGame.twoPointersMade, perGame.twoPointersAttempted), color: color)
                StatRing(title: "3PT", percentage: totals.threePointPercentage,
                         detail: Self.detail(perGame.threePointersMade, perGame.threePointersAttempted), color: color)
                StatRing(title: "FT", percentage: totals.freeThrowPercentage,
                         detail: Self.detail(perGame.freeThrowsMade, perGame.freeThrowsAttempted), color: color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.shooting")
    }

    /// "4.2/9.0" made/attempted per game.
    static func detail(_ made: Double, _ attempted: Double) -> String {
        "\(Format.average(made))/\(Format.average(attempted))"
    }
}

// MARK: - Game log

private struct GameLog: View {
    let rows: [PlayerPage.LogRow]
    let appModel: AppModel
    let onSelect: (Route) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Game log")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Opponent").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(["MIN", "PTS", "REB", "AST"], id: \.self) { Text(verbatim: $0).frame(width: 36, alignment: .trailing) }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .accessibilityHidden(true)
                ForEach(rows) { row in
                    Button { onSelect(.game(id: row.id)) } label: { rowView(row) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("player.game.\(row.id)")
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("player.log")
    }

    private func rowView(_ row: PlayerPage.LogRow) -> some View {
        let opponent = appModel.club(id: row.opponent.id) ?? Club(team: row.opponent, settings: appModel.config?.teams[row.opponent.id])
        let stats = row.line.stats
        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(verbatim: row.isHome ? "vs" : "@").font(.caption).foregroundStyle(Theme.textTertiary).frame(width: 18)
                ClubLogo(club: opponent, size: 22)
                Text(verbatim: opponent.shortName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                if let won = row.won, let own = row.teamScore, let other = row.opponentScore {
                    Text(verbatim: "\(won ? "W" : "L") \(own)-\(other)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(won ? Theme.win : Theme.loss)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Group {
                Text(verbatim: Format.count(stats.minutes)).frame(width: 36, alignment: .trailing)
                Text(verbatim: Format.count(stats.points)).frame(width: 36, alignment: .trailing)
                    .fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                Text(verbatim: Format.count(stats.rebounds)).frame(width: 36, alignment: .trailing)
                Text(verbatim: Format.count(stats.assists)).frame(width: 36, alignment: .trailing)
            }
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(row.isHome ? String(localized: "versus") : String(localized: "at")) \(opponent.displayName)"))
        .accessibilityValue(Text(verbatim: [
            row.won.map { $0 ? String(localized: "won") : String(localized: "lost") },
            row.teamScore.flatMap { own in row.opponentScore.map { "\(own)-\($0)" } },
            String(localized: "\(Format.count(stats.points)) points, \(Format.count(stats.rebounds)) rebounds, \(Format.count(stats.assists)) assists")
        ].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
    }
}
