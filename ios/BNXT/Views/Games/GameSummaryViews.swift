import SwiftUI

/// Summary tab (§3.4): top performer per club, team comparison bars, game leaders.
struct GameSummary: View {
    let model: GameViewModel
    let game: Game
    let club: (Team) -> Club
    let onSelect: (Route) -> Void

    var body: some View {
        let home = model.teamBox(.home), away = model.teamBox(.away)
        if home == nil && away == nil {
            NoBoxScoreNote()
        } else {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Top performers")
                    HStack(alignment: .top, spacing: 10) {
                        performer(GameDetail.topPerformer(home), club: club(game.home.team))
                        performer(GameDetail.topPerformer(away), club: club(game.away.team))
                    }
                }
                if let home, let away {
                    comparison(GameDetail.comparison(home: home.totals, away: away.totals))
                }
                leaders(home: home, away: away)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game.summary")
        }
    }

    @ViewBuilder
    private func performer(_ line: PlayerBoxLine?, club: Club) -> some View {
        if let line {
            Button { if line.rosterId > 0 { onSelect(.player(rosterId: line.rosterId)) } } label: {
                VStack(spacing: 8) {
                    PlayerAvatar(player: line.player, size: 64)
                    VStack(spacing: 2) {
                        Text(verbatim: line.player.fullName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        HStack(spacing: 4) {
                            ClubLogo(club: club, size: 14)
                            Text(verbatim: [club.shortName, line.jersey.map { "#\($0)" }].compactMap { $0 }.joined(separator: " · "))
                        }
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                    }
                    Text(verbatim: "\(Format.count(line.stats.points)) PTS · \(Format.count(line.stats.rebounds)) REB · "
                        + "\(Format.count(line.stats.assists)) AST")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.textPrimary)
                    Text(verbatim: "VAL \(Format.count(line.stats.efficiency))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.lime)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("game.topPerformer.\(club.shortName)")
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private func comparison(_ rows: [GameDetail.ComparisonRow]) -> some View {
        let homeColor = club(game.home.team).graphicColor.color, awayColor = club(game.away.team).graphicColor.color
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Team comparison")
            VStack(spacing: 14) {
                ForEach(rows) { row in
                    VStack(spacing: 4) {
                        HStack {
                            value(row.home, row: row, isBetter: row.better == .home)
                            Spacer()
                            Text(verbatim: row.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            value(row.away, row: row, isBetter: row.better == .away)
                        }
                        GeometryReader { proxy in
                            HStack(spacing: 3) {
                                Capsule().fill(row.better == .home ? homeColor : Theme.surface3)
                                    .frame(width: max(4, (proxy.size.width - 3) * row.homeShare))
                                Capsule().fill(row.better == .away ? awayColor : Theme.surface3)
                            }
                        }
                        .frame(height: 6)
                        if let homeDetail = row.homeDetail, let awayDetail = row.awayDetail {
                            HStack {
                                Text(verbatim: homeDetail)
                                Spacer()
                                Text(verbatim: awayDetail)
                            }
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: row.title))
                    .accessibilityValue(Text(verbatim: "\(club(game.home.team).displayName) \(text(row.home, row: row)), "
                        + "\(club(game.away.team).displayName) \(text(row.away, row: row))"))
                }
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityIdentifier("game.comparison")
        }
    }

    private func text(_ value: Double, row: GameDetail.ComparisonRow) -> String {
        row.isPercentage ? Format.percentage(value) : Format.count(value)
    }

    private func value(_ number: Double, row: GameDetail.ComparisonRow, isBetter: Bool) -> some View {
        Text(verbatim: text(number, row: row))
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(isBetter || row.better == .neither ? Theme.textPrimary : Theme.textTertiary)
    }

    private func leaders(home: TeamBoxScore?, away: TeamBoxScore?) -> some View {
        let stats: [(LocalizedStringKey, KeyPath<StatLine, Double>)] = [("Points", \.points), ("Rebounds", \.rebounds), ("Assists", \.assists)]
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Game leaders")
            VStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    HStack {
                        leader(GameDetail.leader(home, stat.1), stat: stat.1, alignment: .leading)
                        Text(stat.0).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
                        leader(GameDetail.leader(away, stat.1), stat: stat.1, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    @ViewBuilder
    private func leader(_ line: PlayerBoxLine?, stat: KeyPath<StatLine, Double>, alignment: HorizontalAlignment) -> some View {
        if let line {
            Button { if line.rosterId > 0 { onSelect(.player(rosterId: line.rosterId)) } } label: {
                HStack(spacing: 8) {
                    if alignment == .leading { PlayerAvatar(player: line.player, size: 32) }
                    VStack(alignment: alignment, spacing: 0) {
                        Text(verbatim: line.player.lastName).font(.footnote.weight(.semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                        Text(verbatim: Format.count(line.stats[keyPath: stat])).font(Theme.score(.callout)).foregroundStyle(Theme.textPrimary)
                    }
                    if alignment == .trailing { PlayerAvatar(player: line.player, size: 32) }
                }
                .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        } else {
            Spacer().frame(maxWidth: .infinity)
        }
    }
}

/// Box score tab (§3.4): club switch and the shared `BoxScoreTable`.
struct GameBoxScore: View {
    @Bindable var model: GameViewModel
    let game: Game
    let club: (Team) -> Club
    let onSelect: (Route) -> Void

    var body: some View {
        if let box = model.teamBox(model.boxSide) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    sideButton(.home, club: club(game.home.team))
                    sideButton(.away, club: club(game.away.team))
                }
                // Players the rosters don't know (negative placeholder ids, live only) don't open a page.
                BoxScoreTable(box: box) { line in if line.rosterId > 0 { onSelect(.player(rosterId: line.rosterId)) } }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("game.boxScore")
                if model.isLiveBox {
                    Text("Live box score: FIBA LiveStats. The official one replaces it after the game.")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 4)
                        .accessibilityIdentifier("game.liveBoxNote")
                }
                Text("Starters are marked with a dot. Scroll the table sideways for more; tap a player for their page.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }
        } else {
            NoBoxScoreNote()
        }
    }

    private func sideButton(_ side: GameViewModel.Side, club: Club) -> some View {
        let selected = model.boxSide == side
        return Button { model.boxSide = side } label: {
            HStack(spacing: 6) {
                ClubLogo(club: club, size: 20)
                Text(verbatim: club.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(selected ? Theme.ink : Theme.textSecondary)
            .background(selected ? Theme.textPrimary : Theme.surface2, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("game.boxSide.\(club.shortName)")
    }
}

private struct NoBoxScoreNote: View {
    var body: some View {
        Text("The box score isn't available yet.")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 100)
            .accessibilityIdentifier("game.noBoxScore")
    }
}
