import SwiftUI

/// Live play-by-play (§3.4): newest first, the score after each scoring play, a 3PT marker, a header per period.
/// Substitutions and period markers are left out.
struct PlayByPlay: View {
    let plays: [LivePlay]
    let home: Club
    let away: Club

    /// Plays grouped by period, newest period first, keeping the feed's newest-first order inside each.
    static func periods(_ plays: [LivePlay]) -> [(label: String, plays: [LivePlay])] {
        var groups: [(label: String, plays: [LivePlay])] = []
        for play in plays where play.kind.isNarrated {
            let label = LiveFeed(clock: "", period: play.period, isOvertime: play.isOvertime, homeScore: 0, awayScore: 0, plays: []).periodLabel
            if groups.last?.label == label {
                groups[groups.count - 1].plays.append(play)
            } else {
                groups.append((label, [play]))
            }
        }
        return groups
    }

    var body: some View {
        let periods = Self.periods(plays)
        if periods.isEmpty {
            Text("Play-by-play isn't available for this game right now.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 100)
                .accessibilityIdentifier("game.noPlays")
        } else {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(periods, id: \.label) { period in
                    Text(verbatim: period.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 4)
                        .accessibilityAddTraits(.isHeader)
                    VStack(spacing: 0) {
                        ForEach(period.plays) { play in row(play) }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                Text("Live data: FIBA LiveStats.")
                    .font(.caption)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game.plays")
        }
    }

    private func row(_ play: LivePlay) -> some View {
        let club = play.side == 1 ? home : play.side == 2 ? away : nil
        return HStack(spacing: 10) {
            Text(verbatim: play.clock)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 42, alignment: .leading)
            // A plain badge, not the logo: rows re-render on every poll and shouldn't reload images.
            Text(verbatim: club?.shortName ?? "")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 34, height: 20)
                .background((club?.graphicColor ?? .violet).color.opacity(club == nil ? 0 : 0.35), in: Capsule())
                .accessibilityHidden(true)
            Text(verbatim: play.line)
                .font(.subheadline.weight(play.isScore ? .semibold : .regular))
                .foregroundStyle(play.isScore ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(2)
            if play.isScore && play.kind == .threePointer {
                Text(verbatim: "3PT")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundStyle(Theme.ink)
                    .background(Theme.lime, in: Capsule())
            }
            Spacer(minLength: 4)
            if play.isScore {
                Text(verbatim: "\(play.homeScore)–\(play.awayScore)")
                    .font(Theme.compactNumber(.subheadline))
                    .foregroundStyle(Theme.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: [play.clock, club?.displayName, play.line].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityValue(Text(verbatim: play.isScore ? "\(home.displayName) \(play.homeScore), \(away.displayName) \(play.awayScore)" : ""))
    }
}
