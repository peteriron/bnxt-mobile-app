import SwiftUI

/// Home's 2×2 club leaders (PTS, REB, AST, VAL).
struct HomeClubLeaders: View {
    let leaders: [HomePage.ClubLeader]
    let onSelect: (Route) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let perRow = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(Array(stride(from: 0, to: leaders.count, by: perRow)), id: \.self) { start in
                GridRow {
                    ForEach(leaders[start..<min(start + perRow, leaders.count)]) { leader in clubLeaderTile(leader) }
                    if start + perRow > leaders.count { Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.clubLeaders")
    }

    private func clubLeaderTile(_ leader: HomePage.ClubLeader) -> some View {
        Button { onSelect(.player(rosterId: leader.player.rosterId)) } label: {
            HStack(spacing: 10) {
                PlayerAvatar(player: leader.player.player, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: leader.stat.rawValue).font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                    Text(verbatim: Format.average(leader.value)).font(Theme.score(.title3)).foregroundStyle(Theme.textPrimary)
                    Text(verbatim: leader.player.player.shortName)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .oneLineUnlessAccessibilitySize()
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(leader.stat.rawValue): \(leader.player.player.fullName)"))
        .accessibilityValue(Text(verbatim: Format.average(leader.value)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.clubLeader.\(leader.stat.rawValue)")
    }
}

/// Home's league VAL top 3.
struct HomeLeagueLeaders: View {
    let entries: [LeaderEntry]
    let club: (Team) -> Club
    let onSelect: (Route) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.rosterId) { index, entry in
                let entryClub = club(entry.team)
                Button { onSelect(.player(rosterId: entry.rosterId)) } label: {
                    HStack(spacing: 12) {
                        Text(verbatim: "\(index + 1)")
                            .font(Theme.compactNumber(.subheadline))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(width: 20)
                        PlayerAvatar(player: entry.player, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: entry.player.fullName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            Text(verbatim: entryClub.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                            if dynamicTypeSize.isAccessibilitySize {
                                Text(verbatim: "\(Format.average(entry.value)) VAL").font(Theme.compactNumber(.body)).foregroundStyle(Theme.textPrimary)
                            }
                        }
                        Spacer()
                        if !dynamicTypeSize.isAccessibilitySize {
                            VStack(alignment: .trailing, spacing: 0) {
                                Text(verbatim: Format.average(entry.value)).font(Theme.compactNumber(.body)).foregroundStyle(Theme.textPrimary)
                                Text(verbatim: "VAL").font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 58)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: "\(index + 1). \(entry.player.fullName), \(entryClub.displayName)"))
                .accessibilityValue(Text(verbatim: "\(Format.average(entry.value)) VAL"))
                .accessibilityAddTraits(.isButton)
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.leagueLeaders")
    }
}

/// Home's carousel of the latest round's results.
struct HomeAroundTheLeague: View {
    let games: [Game]
    let now: Date
    let club: (Team) -> Club
    let onSelect: (Route) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var cardWidth: CGFloat = 150

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(games) { game in
                    Button { onSelect(.game(id: game.id)) } label: { resultCard(game) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.result.\(game.id)")
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.around")
    }

    private func resultCard(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: Format.relativeDay(game.tipOff, now: now))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(Theme.textTertiary)
            resultLine(game.home, won: game.winner?.id == game.home.team.id)
            resultLine(game.away, won: game.winner?.id == game.away.team.id)
        }
        .padding(12)
        .frame(width: cardWidth)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(club(game.home.team).displayName) \(game.home.score ?? 0), "
                                 + "\(club(game.away.team).displayName) \(game.away.score ?? 0)"))
        .accessibilityAddTraits(.isButton)
    }

    private func resultLine(_ side: GameSide, won: Bool) -> some View {
        HStack(spacing: 8) {
            ClubLogo(club: club(side.team), size: 22)
            Text(verbatim: club(side.team).shortName)
                .font(.subheadline.weight(won ? .bold : .regular))
            Spacer()
            Text(verbatim: side.score.map(String.init) ?? "")
                .font(Theme.compactNumber(.body))
        }
        .foregroundStyle(won ? Theme.textPrimary : Theme.textSecondary)
    }
}

/// Home's standing card: position, record and streak, national rank and playoff status, a 5-row snippet.
struct HomeStandingCard: View {
    let summary: HomePage.StandingSummary
    let clubId: Int?
    let club: (Team) -> Club
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let standing = summary.standing
        return Button(action: action) {
            VStack(spacing: 0) {
                AdaptiveStack(verticalAlignment: .center, spacing: 14) {
                    Text(verbatim: Format.ordinal(standing.position))
                        .font(Theme.score(.largeTitle))
                        .foregroundStyle(Theme.textPrimary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: [String(localized: "\(standing.wins)–\(standing.losses)"),
                                        standing.streak.map(Format.streakDescription)].compactMap { $0 }.joined(separator: " · "))
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(verbatim: Self.detail(summary))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                ForEach(summary.snippet) { row in snippetRow(row, isMine: row.id == clubId) }
            }
            .padding(.bottom, 6)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Standing: \(Format.ordinal(standing.position)) in the league"))
        .accessibilityValue(Text(verbatim: Self.detail(summary)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("home.standing")
    }

    /// "3rd of the Belgian clubs · in a playoff place".
    static func detail(_ summary: HomePage.StandingSummary) -> String {
        var parts: [String] = []
        if let rank = summary.nationalRank, let country = summary.country {
            let ordinal = Format.ordinal(rank)
            parts.append(country == .belgium ? String(localized: "\(ordinal) of the Belgian clubs")
                                             : String(localized: "\(ordinal) of the Dutch clubs"))
        }
        switch summary.playoffStatus {
        case .leader: parts.append(String(localized: "top of the league"))
        case .playoffPlace: parts.append(String(localized: "in a playoff place"))
        case .outside: parts.append(String(localized: "outside the playoff places"))
        case .unknown: break
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func snippetRow(_ row: StandingsTable.Row, isMine: Bool) -> some View {
        let standing = row.standing
        let record = "\(standing.wins)–\(standing.losses)", difference = Format.plusMinus(Double(standing.pointDifference))
        let zone = Rectangle().fill(row.zone.flatMap { RGB(hexString: $0.color) }?.color ?? .clear).frame(width: 3)
        let name = Text(verbatim: club(standing.team).displayName)
            .font(.subheadline.weight(isMine ? .bold : .regular))
            .foregroundStyle(Theme.textPrimary)
        let rank = Text(verbatim: "\(row.rank)").font(Theme.compactNumber(.subheadline)).foregroundStyle(Theme.textTertiary)
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Two lines: fixed-width number columns would break the digits apart.
                HStack(alignment: .top, spacing: 10) {
                    zone
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) { rank; name }
                        Text(verbatim: "\(record) · \(difference)")
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 10) {
                    zone.frame(height: 22)
                    rank.frame(width: 22)
                    ClubLogo(club: club(standing.team), size: 22)
                    name.lineLimit(1)
                    Spacer()
                    Text(verbatim: record).frame(width: 44, alignment: .trailing)
                    Text(verbatim: difference).frame(width: 44, alignment: .trailing)
                }
            }
        }
        .font(.subheadline)
        .monospacedDigit()
        .foregroundStyle(Theme.textSecondary)
        .padding(.trailing, 14)
        .frame(minHeight: 36)
        .background(isMine ? Theme.lime.opacity(0.08) : .clear)
    }
}
