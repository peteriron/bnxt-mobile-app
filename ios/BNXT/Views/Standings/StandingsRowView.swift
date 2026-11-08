import SwiftUI

/// Column widths shared by the standings header and rows.
enum StandingsLayout {
    static let rank: CGFloat = 40
    static let number: CGFloat = 28
    static let difference: CGFloat = 44
    static let streak: CGFloat = 40
}

/// One standings row (§3.5): columns at regular sizes, two spelled-out lines at accessibility sizes.
struct StandingsRowView: View {
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
