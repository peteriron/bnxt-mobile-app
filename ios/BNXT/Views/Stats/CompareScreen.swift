import SwiftUI

/// Compare players (§3.7): two slots (A violet, B orange) and 12 mirrored bars of season averages.
/// Tapping a slot opens a searchable picker.
struct CompareScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void

    @State private var model: CompareViewModel
    @State private var picking: PlayerComparison.Side?

    init(presetRosterId: Int?, appModel: AppModel, favorites: FavoriteClubStore, onSelect: @escaping (Route) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelect = onSelect
        _model = State(initialValue: CompareViewModel(presetRosterId: presetRosterId, api: appModel.api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch model.state {
                case .idle, .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 300)
                case .failed:
                    LoadFailedView { Task { await load(refresh: true) } }
                case .loaded:
                    if let cachedAt = model.cachedAt { CachedNote(date: cachedAt) }
                    AdaptiveStack(spacing: 10) {
                        ForEach(PlayerComparison.Side.allCases, id: \.self) { side in
                            CompareSlot(side: side, candidate: model.player(on: side), club: club(model.player(on: side)?.teamId)) {
                                picking = side
                            }
                        }
                    }
                    bars
                    Text("Per-game season averages, \(appModel.season.label). The better value in each row is highlighted.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .background(Theme.ink)
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load(refresh: true) }
        .task { if model.state == .idle { await load(refresh: false) } }
        .sheet(item: $picking) { side in
            ComparePicker(side: side, candidates: model.candidates, appModel: appModel) { rosterId in
                model.choose(rosterId, for: side)
                picking = nil
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.compare")
    }

    private func load(refresh: Bool) async {
        await model.load(season: appModel.season, teamIds: appModel.clubs.map(\.id), favoriteClubId: favorites.clubId, refresh: refresh)
    }

    private func club(_ id: Int?) -> Club? { appModel.club(id: id) }

    private var bars: some View {
        let playerA = model.playerA, playerB = model.playerB
        return VStack(spacing: 4) {
            ForEach(CompareStat.allCases) { stat in
                MirrorRow(stat: stat, valueA: playerA.flatMap(stat.value), valueB: playerB.flatMap(stat.value),
                          nameA: playerA?.player.fullName, nameB: playerB?.player.fullName, gamesPerTeam: appModel.season.gamesPerTeam)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare.bars")
    }
}

extension PlayerComparison.Side: Identifiable {
    var id: Self { self }

    /// A violet, B orange (§5.1).
    var color: Color { self == .first ? Theme.violet : Theme.orange }
    /// Text-safe variant of the side colour.
    var textColor: Color { self == .first ? Theme.violetHigh : Theme.orange }

    var title: LocalizedStringKey { self == .first ? "Player 1" : "Player 2" }
}

// MARK: - Slots

private struct CompareSlot: View {
    let side: PlayerComparison.Side
    let candidate: CompareCandidate?
    let club: Club?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let player = candidate?.player {
                    PlayerAvatar(player: player, size: 68)
                    Text(verbatim: player.fullName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(minHeight: 36)
                    HStack(spacing: 5) {
                        ClubLogo(club: club, size: 14)
                        Text(verbatim: club?.displayName ?? "").font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                } else {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(height: 68)
                    Text("Choose a player").font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
                }
                Text("Change")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(side.textColor)
                    .background(side.color.opacity(Theme.badgeTintOpacity), in: Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(side.color, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(side.title)
        .accessibilityValue(Text(verbatim: [candidate?.player.fullName, club?.displayName].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityHint("Choose another player")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("compare.slot.\(side.rawValue)")
    }
}

// MARK: - Bars

private struct MirrorRow: View {
    let stat: CompareStat
    let valueA: Double?
    let valueB: Double?
    let nameA: String?
    let nameB: String?
    let gamesPerTeam: Int

    var body: some View {
        let better = PlayerComparison.better(stat, first: valueA, second: valueB)
        let scale = stat.scale(gamesPerTeam: gamesPerTeam)
        VStack(spacing: 4) {
            Text(stat.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 8) {
                value(valueA, side: .first, wins: better == .first)
                bar(valueA, scale: scale, side: .first, wins: better == .first)
                bar(valueB, scale: scale, side: .second, wins: better == .second)
                value(valueB, side: .second, wins: better == .second)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(stat.title)
        .accessibilityValue(Text(verbatim: accessibilityValue(better: better)))
        .accessibilityIdentifier("compare.row.\(stat.rawValue)")
    }

    private func value(_ value: Double?, side: PlayerComparison.Side, wins: Bool) -> some View {
        Text(verbatim: stat.formatted(value))
            .font(Theme.compactNumber(.subheadline))
            .foregroundStyle(wins ? Theme.textPrimary : Theme.textTertiary)
            .fixedSize() // grows with the text instead of breaking "17,7" over three lines
            .frame(minWidth: 48, alignment: side == .first ? .leading : .trailing)
    }

    /// A grows leftwards from the centre, B rightwards.
    private func bar(_ value: Double?, scale: Double, side: PlayerComparison.Side, wins: Bool) -> some View {
        let fraction = min(max((value ?? 0) / scale, 0), 1)
        return Capsule()
            .fill(Theme.surface3)
            .frame(height: 8)
            .overlay(alignment: side == .first ? .trailing : .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(wins ? side.color : Theme.textTertiary.opacity(0.6))
                        .frame(width: proxy.size.width * fraction)
                        .frame(maxWidth: .infinity, alignment: side == .first ? .trailing : .leading)
                }
            }
    }

    private func accessibilityValue(better: PlayerComparison.Side?) -> String {
        var parts = [
            "\(nameA ?? String(localized: "Player 1")) \(stat.formatted(valueA))",
            "\(nameB ?? String(localized: "Player 2")) \(stat.formatted(valueB))"
        ]
        switch better {
        case .first: parts.append(String(localized: "\(nameA ?? "") is better"))
        case .second: parts.append(String(localized: "\(nameB ?? "") is better"))
        case nil: parts.append(String(localized: "Level"))
        }
        return parts.joined(separator: ", ")
    }
}

extension CompareStat {
    var title: LocalizedStringKey {
        switch self {
        case .points: "Points"
        case .rebounds: "Rebounds"
        case .assists: "Assists"
        case .steals: "Steals"
        case .blocks: "Blocks"
        case .turnovers: "Turnovers"
        case .fieldGoalPercentage: "FG%"
        case .threePointPercentage: "3P%"
        case .freeThrowPercentage: "FT%"
        case .efficiency: "Efficiency (VAL)"
        case .minutes: "Minutes"
        case .gamesPlayed: "Games"
        }
    }
}

// MARK: - Picker

/// "Choose player 1/2": every player who has played, best VAL first, searchable by player or club.
private struct ComparePicker: View {
    let side: PlayerComparison.Side
    let candidates: [CompareCandidate]
    let appModel: AppModel
    let onPick: (Int) -> Void

    @State private var query = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let results = PlayerComparison.search(candidates, query: query) { teamId in
            appModel.club(id: teamId).map { [$0.displayName, $0.officialName, $0.shortName] } ?? []
        }
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(results) { candidate in
                        Button { onPick(candidate.id) } label: { row(candidate) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("compare.option.\(candidate.id)")
                    }
                    if results.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                }
            }
            .background(Theme.ink)
            .navigationTitle(side == .first ? "Choose player 1" : "Choose player 2")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search by player or club"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.accessibilityIdentifier("compare.picker.cancel")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("compare.picker")
    }

    private func row(_ candidate: CompareCandidate) -> some View {
        let club = appModel.club(id: candidate.teamId)
        let line = candidate.perGame
        return HStack(spacing: 12) {
            PlayerAvatar(player: candidate.player, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: candidate.player.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: "\(club?.displayName ?? "") · \(Format.average(line.points)) PTS · \(Format.average(line.efficiency)) VAL")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
