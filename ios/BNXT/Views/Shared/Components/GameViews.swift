import SwiftUI

/// LIVE (pulsing), FINAL, or the tip-off time.
struct StatusPill: View {
    let label: GameStatusLabel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        switch label {
        case let .live(period):
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.live)
                    .frame(width: 6, height: 6)
                    .opacity(pulse ? 0.25 : 1)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true }
                    }
                Text("LIVE")
                if let period { Text(verbatim: period) }
            }
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.live)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.live.opacity(0.16), in: Capsule())
            .accessibilityElement(children: .combine)
        case .final:
            Text("Final")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        case let .scheduled(time):
            Text(verbatim: time)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

/// One game in a list: both clubs with scores, and a status column (prototype `.g-row`).
struct GameRow: View {
    let game: Game
    let home: Club?
    let away: Club?
    var favoriteClubId: Int?
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                side(game.home, club: home, opponentScore: game.away.score)
                side(game.away, club: away, opponentScore: game.home.score)
            }
            Divider().overlay(Theme.surface3)
            VStack(alignment: .trailing, spacing: 3) {
                StatusPill(label: GameStatusLabel(game: game))
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 76, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    private func side(_ side: GameSide, club: Club?, opponentScore: Int?) -> some View {
        let dimmed = game.status == .finished && (side.score ?? 0) < (opponentScore ?? 0)
        return HStack(spacing: 10) {
            ClubLogo(club: club, size: 26)
            Text(verbatim: club?.displayName ?? side.team.name)
                .font(.body.weight(dimmed ? .regular : .semibold))
                .foregroundStyle(dimmed ? Theme.textSecondary : Theme.textPrimary)
                .lineLimit(1)
            if side.team.id == favoriteClubId {
                Circle().fill(Theme.lime).frame(width: 6, height: 6).accessibilityHidden(true)
            }
            Spacer(minLength: 4)
            if let score = side.score {
                Text(verbatim: "\(score)")
                    .font(Theme.score(.title3))
                    .foregroundStyle(dimmed ? Theme.textSecondary : Theme.textPrimary)
            }
        }
    }

    private var accessibilityText: String {
        let homeName = home?.displayName ?? game.home.team.name
        let awayName = away?.displayName ?? game.away.team.name
        switch GameStatusLabel(game: game) {
        case .final:
            return "\(homeName) \(game.home.score ?? 0), \(awayName) \(game.away.score ?? 0), " + String(localized: "final")
        case let .live(period):
            return "\(homeName) \(game.home.score ?? 0), \(awayName) \(game.away.score ?? 0), " + String(localized: "live") + (period.map { " \($0)" } ?? "")
        case let .scheduled(time):
            return "\(homeName) " + String(localized: "versus") + " \(awayName), \(subtitle.map { "\($0) " } ?? "")\(time)"
        }
    }
}

/// The big live score card on Home (prototype `.livecard`): club-colour gradient, score, period, last play.
struct LiveCard: View {
    let game: Game
    let home: Club?
    let away: Club?
    var lastPlay: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusPill(label: GameStatusLabel(game: game))
            HStack {
                team(home, fallback: game.home.team)
                Spacer()
                Text(verbatim: "\(game.home.score ?? 0) – \(game.away.score ?? 0)")
                    .font(Theme.score(.largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Spacer()
                team(away, fallback: game.away.team)
            }
            if let lastPlay {
                Text(verbatim: lastPlay)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.ink.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(16)
        .background {
            LinearGradient(colors: [(home?.graphicColor ?? .violet).color.opacity(0.55), Theme.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Theme.surface3, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    private func team(_ club: Club?, fallback: Team) -> some View {
        VStack(spacing: 6) {
            ClubLogo(club: club, size: 48)
            Text(verbatim: club?.displayName ?? fallback.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(width: 92)
    }
}
