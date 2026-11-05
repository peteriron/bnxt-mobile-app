import SwiftUI

/// The club page's sortable per-game table (§3.8): a pinned name column and scrolling stats.
struct PlayerStatsTable: View {
    @Bindable var model: ClubViewModel
    let onSelect: (Route) -> Void

    private let nameWidth: CGFloat = 132
    private let columnWidth: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "PLAYER").font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                        .frame(width: nameWidth, height: 32, alignment: .leading)
                    ForEach(model.playerStats) { line in
                        Button { onSelect(.player(rosterId: line.rosterId)) } label: {
                            Text(verbatim: line.player.shortName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)
                                .frame(width: nameWidth, height: 40, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 12)
                .background(Theme.surface)
                .zIndex(1)

                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            header("GP", sortable: nil)
                            ForEach(ClubPage.StatColumn.allCases) { header($0.rawValue, sortable: $0) }
                            header("FG%", sortable: nil)
                            header("3P%", sortable: nil)
                            header("FT%", sortable: nil)
                        }
                        ForEach(model.playerStats) { line in
                            HStack(spacing: 0) {
                                cell("\(line.gamesPlayed)", highlighted: false)
                                ForEach(ClubPage.StatColumn.allCases) { column in
                                    cell(Format.average(column.value(line.perGame)), highlighted: column == model.statSort)
                                }
                                cell(Format.percentage(line.perGame.fieldGoalPercentage), highlighted: false)
                                cell(Format.percentage(line.perGame.threePointPercentage), highlighted: false)
                                cell(Format.percentage(line.perGame.freeThrowPercentage), highlighted: false)
                            }
                            .frame(height: 40)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: line.player.fullName))
                            .accessibilityValue(Text(verbatim: ClubPage.StatColumn.allCases
                                .map { "\($0.rawValue) \(Format.average($0.value(line.perGame)))" }.joined(separator: ", ")))
                        }
                    }
                    .padding(.trailing, 12)
                }
            }
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("club.playerStats")

            Text("Per-game averages. Tap a column heading to sort by it.")
                .font(.caption)
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func header(_ title: String, sortable column: ClubPage.StatColumn?) -> some View {
        let label = Text(verbatim: title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(column != nil && column == model.statSort ? Theme.lime : Theme.textTertiary)
            .frame(width: columnWidth, height: 32, alignment: .trailing)
        if let column {
            Button { model.statSort = column } label: { label }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Sort by \(title)"))
                .accessibilityAddTraits(column == model.statSort ? .isSelected : [])
                .accessibilityIdentifier("club.sort.\(title)")
        } else {
            label
        }
    }

    private func cell(_ text: String, highlighted: Bool) -> some View {
        Text(verbatim: text)
            .font(.subheadline.weight(highlighted ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(highlighted ? Theme.textPrimary : Theme.textSecondary)
            .frame(width: columnWidth, alignment: .trailing)
    }
}
