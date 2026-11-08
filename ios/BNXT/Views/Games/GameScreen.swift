import SwiftUI

/// Game detail (§3.4): header, quarter table and the tabs for the game's state.
struct GameScreen: View {
    let appModel: AppModel
    let onSelect: (Route) -> Void

    @State private var model: GameViewModel

    init(gameId: Int, appModel: AppModel, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.onSelect = onSelect
        _model = State(initialValue: GameViewModel(gameId: gameId, api: appModel.api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case .failed:
                    LoadFailedView { Task { await model.load(season: appModel.season, liveStatsEnabled: liveStatsEnabled) } }
                case .loaded:
                    if let game = model.game { content(game) }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(alignment: .top) { headerGradient.ignoresSafeArea() }
        .background(Theme.ink)
        .navigationTitle(Text(verbatim: title))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await model.load(season: appModel.season, liveStatsEnabled: liveStatsEnabled) }
        .task { if model.state == .idle { await model.load(season: appModel.season, liveStatsEnabled: liveStatsEnabled) } }
        // Live polling only while this screen is visible: the task ends when it goes away (§4 Network etiquette).
        .task(id: model.game?.isLive == true) {
            if model.game?.isLive == true {
                await model.watchLive(season: appModel.season, liveStatsEnabled: liveStatsEnabled)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.game.\(model.gameId)")
    }

    private var liveStatsEnabled: Bool { appModel.config?.features.liveStats ?? true }

    private var title: String {
        guard let game = model.game else { return "" }
        let middle = game.hasStarted ? "\(game.home.score ?? 0)–\(game.away.score ?? 0)" : "vs"
        return "\(game.home.team.shortName) \(middle) \(game.away.team.shortName)"
    }

    func club(_ team: Team) -> Club {
        appModel.club(id: team.id) ?? Club(team: team, settings: appModel.config?.teams[team.id])
    }

    private var headerGradient: some View {
        let home = model.game.map { club($0.home.team).graphicColor } ?? .violet
        let away = model.game.map { club($0.away.team).graphicColor } ?? .violet
        return ZStack {
            LinearGradient(colors: [home.color.opacity(0.45), .clear], startPoint: .topLeading, endPoint: .center)
            LinearGradient(colors: [away.color.opacity(0.45), .clear], startPoint: .topTrailing, endPoint: .center)
        }
        .frame(height: 420)
    }

    @ViewBuilder
    private func content(_ game: Game) -> some View {
        @Bindable var model = model
        GameHeader(game: game, home: club(game.home.team), away: club(game.away.team),
                   homeStanding: model.standings[game.home.team.id], awayStanding: model.standings[game.away.team.id]) { onSelect(.club(id: $0)) }
        if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
        if game.hasStarted { QuarterTable(game: game, home: club(game.home.team), away: club(game.away.team)) }

        Picker("Section", selection: Binding(get: { model.selectedTab ?? .info }, set: { model.tab = $0 })) {
            ForEach(model.tabs, id: \.self) { tab in Text(tab.title).tag(tab) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("game.tabs")

        switch model.selectedTab {
        case .playByPlay:
            PlayByPlay(plays: model.liveFeed?.plays ?? [], home: club(game.home.team), away: club(game.away.team))
        case .summary:
            GameSummary(model: model, game: game, club: club, onSelect: onSelect)
        case .boxScore:
            GameBoxScore(model: model, game: game, club: club, onSelect: onSelect)
        case .preview:
            GamePreview(model: model, game: game, club: club, onSelect: onSelect)
        case .info, nil:
            GameInfo(game: game, home: club(game.home.team))
        }
    }
}

extension GameDetail.Tab {
    var title: LocalizedStringKey {
        switch self {
        case .playByPlay: "Plays"
        case .summary: "Summary"
        case .boxScore: "Box score"
        case .preview: "Preview"
        case .info: "Info"
        }
    }
}

// MARK: - Header

private struct GameHeader: View {
    let game: Game
    let home: Club
    let away: Club
    let homeStanding: Standing?
    let awayStanding: Standing?
    let openClub: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text("BNXT League · Regular season")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.textSecondary)
                status
            }
            AdaptiveStack(horizontalAlignment: .center, verticalAlignment: .center, spacing: 8) {
                team(home, standing: homeStanding, side: "Home")
                middle.frame(minWidth: 120)
                team(away, standing: awayStanding, side: "Away")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.header")
    }

    @ViewBuilder private var status: some View {
        switch game.status {
        case .inProgress:
            StatusPill(label: GameStatusLabel(game: game))
        case .finished:
            Text(verbatim: [String(localized: "Final"), game.arena].compactMap { $0 }.joined(separator: " · "))
                .font(.footnote).foregroundStyle(Theme.textSecondary)
        case .scheduled:
            Text(verbatim: [Format.relativeDay(game.tipOff, now: .now), Format.tipOffTime(game.tipOff), game.arena ?? home.city]
                .compactMap { $0 }.joined(separator: " · "))
                .font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder private var middle: some View {
        if game.hasStarted, let homeScore = game.home.score, let awayScore = game.away.score {
            let winner = game.winner?.id
            HStack(spacing: 6) {
                Text(verbatim: "\(homeScore)")
                    .foregroundStyle(winner == game.away.team.id ? Theme.textTertiary : Theme.textPrimary)
                Text(verbatim: "–").foregroundStyle(Theme.textTertiary)
                Text(verbatim: "\(awayScore)")
                    .foregroundStyle(winner == game.home.team.id ? Theme.textTertiary : Theme.textPrimary)
            }
            .font(Theme.score(.largeTitle))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Score"))
            .accessibilityValue(Text(verbatim: "\(home.displayName) \(homeScore), \(away.displayName) \(awayScore)"))
            .accessibilityIdentifier("game.score")
        } else {
            VStack(spacing: 2) {
                Text(verbatim: Format.tipOffTime(game.tipOff)).font(Theme.score(.title)).foregroundStyle(Theme.textPrimary)
                Text(verbatim: Format.relativeDay(game.tipOff, now: .now))
                    .font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("game.tipOff")
        }
    }

    private func team(_ club: Club, standing: Standing?, side: LocalizedStringKey) -> some View {
        Button { openClub(club.id) } label: {
            VStack(spacing: 6) {
                ClubLogo(club: club, size: 60)
                Text(verbatim: club.displayName)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                // One Text, so it wraps as a sentence instead of splitting into columns.
                (Text(verbatim: standing.map { "\($0.wins)–\($0.losses) · " } ?? "") + Text(side))
                .multilineTextAlignment(.center)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("game.team.\(club.shortName)")
    }
}

// MARK: - Quarters

private struct QuarterTable: View {
    let game: Game
    let home: Club
    let away: Club

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let titles = GameDetail.periodTitles(game)
        Group {
            if dynamicTypeSize.isAccessibilitySize { transposed(titles) } else { columns(titles) }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.quarters")
    }

    /// Accessibility sizes: one row per period and a column per club, so each number gets room.
    private func transposed(_ titles: [String]) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 12, verticalSpacing: 6) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                Text(verbatim: home.shortName)
                Text(verbatim: away.shortName)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                GridRow {
                    Text(verbatim: title).font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary).gridColumnAlignment(.leading)
                    Text(verbatim: game.home.periodScores[safe: index].map { "\($0)" } ?? "–")
                    Text(verbatim: game.away.periodScores[safe: index].map { "\($0)" } ?? "–")
                }
                .foregroundStyle(Theme.textSecondary)
            }
            GridRow {
                Text(verbatim: "T").font(.caption2.weight(.bold)).foregroundStyle(Theme.textTertiary)
                Text(verbatim: game.home.score.map { "\($0)" } ?? "–")
                Text(verbatim: game.away.score.map { "\($0)" } ?? "–")
            }
            .fontWeight(.bold)
            .foregroundStyle(Theme.textPrimary)
        }
        .font(.subheadline)
        .monospacedDigit()
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Quarters"))
        .accessibilityValue(Text(verbatim: [quarters(home, side: game.home), quarters(away, side: game.away)].joined(separator: "; ")))
    }

    private func quarters(_ club: Club, side: GameSide) -> String {
        "\(club.displayName): " + side.periodScores.enumerated().map { "\(GameDetail.periodTitles(game)[$0.offset]) \($0.element)" }
            .joined(separator: ", ")
    }

    private func columns(_ titles: [String]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(maxWidth: .infinity)
                ForEach(titles, id: \.self) { Text(verbatim: $0).frame(width: 34) }
                Text(verbatim: "T").frame(width: 40)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(Theme.textTertiary)
            .frame(height: 30)
            row(home, side: game.home, count: titles.count)
            row(away, side: game.away, count: titles.count)
        }
    }

    private func row(_ club: Club, side: GameSide, count: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                ClubLogo(club: club, size: 20)
                Text(verbatim: club.shortName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<count, id: \.self) { index in
                Text(verbatim: side.periodScores[safe: index].map { "\($0)" } ?? "–").frame(width: 34)
            }
            .foregroundStyle(Theme.textSecondary)
            Text(verbatim: side.score.map { "\($0)" } ?? "–")
                .fontWeight(.bold)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 40)
        }
        .font(.subheadline)
        .monospacedDigit()
        .frame(height: 34)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: club.displayName))
        .accessibilityValue(Text(verbatim: side.periodScores.enumerated().map { "\(GameDetail.periodTitles(game)[$0.offset]) \($0.element)" }
            .joined(separator: ", ")))
    }
}
