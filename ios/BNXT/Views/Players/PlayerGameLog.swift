import SwiftUI

/// The player page's game log (§3.8): opponent, result and MIN PTS REB AST per game.
struct PlayerGameLog: View {
    let rows: [PlayerPage.LogRow]
    let appModel: AppModel
    let onSelect: (Route) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Game log")
            VStack(spacing: 0) {
                if !dynamicTypeSize.isAccessibilitySize { columnTitles }
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

    private var columnTitles: some View {
                HStack(spacing: 0) {
                    Text("Opponent").frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(["MIN", "PTS", "REB", "AST"], id: \.self) { Text(verbatim: $0).frame(width: 36, alignment: .trailing) }
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .frame(height: 32)
                .accessibilityHidden(true)
    }

    private func rowView(_ row: PlayerPage.LogRow) -> some View {
        let opponent = appModel.club(id: row.opponent.id) ?? Club(team: row.opponent, settings: appModel.config?.teams[row.opponent.id])
        let stats = row.line.stats
        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Two lines: the opponent and result, then the numbers spelled out with their names.
                VStack(alignment: .leading, spacing: 4) {
                    opponentLine(row, opponent: opponent)
                    Text(verbatim: "MIN \(Format.count(stats.minutes)) · PTS \(Format.count(stats.points)) · "
                         + "REB \(Format.count(stats.rebounds)) · AST \(Format.count(stats.assists))")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else {
                columnsRow(row, opponent: opponent)
            }
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

    private func opponentLine(_ row: PlayerPage.LogRow, opponent: Club) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: row.isHome ? "vs" : "@").font(.caption).foregroundStyle(Theme.textTertiary)
            ClubLogo(club: opponent, size: 22)
            Text(verbatim: opponent.shortName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            if let won = row.won, let own = row.teamScore, let other = row.opponentScore {
                Text(verbatim: "\(won ? "W" : "L") \(own)-\(other)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(won ? Theme.win : Theme.loss)
            }
        }
    }

    private func columnsRow(_ row: PlayerPage.LogRow, opponent: Club) -> some View {
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
    }
}
