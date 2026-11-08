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
                        PlayerGameLog(rows: model.log, appModel: appModel, onSelect: onSelect)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // No room for the photo beside large text: the names and club take the full width.
            names
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text(verbatim: [player.fullName, jersey.map { "#\($0)" }].compactMap { $0 }.joined(separator: ", ")))
        } else {
            photoHero
        }
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: player.firstName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text(verbatim: player.lastName.uppercased())
                .font(Theme.display(.title))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
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
    }

    private var photoHero: some View {
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
            names
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

    private struct BioItem {
        let value: String?
        let title: LocalizedStringKey
        var accessibilityValue: String?
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let items = [
            BioItem(value: entry?.position?.abbreviation, title: "Position"),
            BioItem(value: entry?.heightCm.map { "\($0) cm" }, title: "Height"),
            BioItem(value: age.map { "\($0)" }, title: "Age"),
            BioItem(value: entry?.player.nationalityCode.map { [Nationality.flag(ioc: $0), $0].compactMap { $0 }.joined(separator: " ") },
                    title: "Nationality", accessibilityValue: entry?.player.nationalityCode.map { Nationality.name(ioc: $0) })
        ]
        TileRows(count: items.count, perRow: dynamicTypeSize.isAccessibilitySize ? 2 : 4) { index in
            item(items[index].value, items[index].title, accessibilityValue: items[index].accessibilityValue)
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
                .oneLineUnlessAccessibilitySize().minimumScaleFactor(0.7)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            let perRow = dynamicTypeSize.isAccessibilitySize ? 2 : 4
            VStack(spacing: 8) {
                TileRows(count: main.count, perRow: perRow) { tile(main[$0], large: true) }
                TileRows(count: more.count, perRow: perRow) { tile(more[$0], large: false) }
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
                    .font(.caption2.weight(.heavy))
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

    private struct Ring {
        let title: LocalizedStringKey
        let percentage: Double?
        let detail: String
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let totals = season.totals, perGame = season.perGame
        let rings = [
            Ring(title: "FG", percentage: totals.fieldGoalPercentage, detail: Self.detail(perGame.fieldGoalsMade, perGame.fieldGoalsAttempted)),
            Ring(title: "2PT", percentage: totals.twoPointPercentage, detail: Self.detail(perGame.twoPointersMade, perGame.twoPointersAttempted)),
            Ring(title: "3PT", percentage: totals.threePointPercentage,
                 detail: Self.detail(perGame.threePointersMade, perGame.threePointersAttempted)),
            Ring(title: "FT", percentage: totals.freeThrowPercentage, detail: Self.detail(perGame.freeThrowsMade, perGame.freeThrowsAttempted))
        ]
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Shooting")
            TileRows(count: rings.count, perRow: dynamicTypeSize.isAccessibilitySize ? 2 : 4, spacing: 12) { index in
                StatRing(title: rings[index].title, percentage: rings[index].percentage, detail: rings[index].detail, color: color)
                    .frame(maxWidth: .infinity)
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
