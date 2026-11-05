import SwiftUI

/// The Clubs tab (§3.8): a search field, then a 3-column grid per country with each club's record and position.
struct ClubsScreen: View {
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelectClub: (Int) -> Void

    @State private var standings: StandingsViewModel
    @State private var query = ""
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Three columns (§3.8); two at accessibility text sizes so names stay readable.
    private var columns: Int { dynamicTypeSize.isAccessibilitySize ? 2 : 3 }

    /// Clubs split into rows of `columns`.
    static func rows(_ clubs: [Club], columns: Int) -> [[Club]] {
        guard columns > 0 else { return [] }
        return stride(from: 0, to: clubs.count, by: columns).map { Array(clubs[$0..<min($0 + columns, clubs.count)]) }
    }

    init(appModel: AppModel, favorites: FavoriteClubStore, onSelectClub: @escaping (Int) -> Void) {
        self.appModel = appModel
        self.favorites = favorites
        self.onSelectClub = onSelectClub
        _standings = State(initialValue: StandingsViewModel(api: appModel.api))
    }

    /// Clubs matching `query` by display name, official name, city or short code.
    static func filter(_ clubs: [Club], query: String) -> [Club] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return clubs }
        return clubs.filter { club in
            [club.displayName, club.officialName, club.city ?? "", club.shortName].contains {
                $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }

    var body: some View {
        let byTeam = Dictionary(standings.standings.map { ($0.team.id, $0) }, uniquingKeysWith: { first, _ in first })
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(appModel.clubsByCountry, id: \.country) { group in
                    let clubs = Self.filter(group.clubs, query: query)
                    if !clubs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(verbatim: group.country.map(ClubPickerGrid.countryTitle) ?? String(localized: "Other"))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                                Spacer()
                                Text("\(group.clubs.count) clubs").font(.footnote).foregroundStyle(Theme.textSecondary)
                            }
                            // Not lazy: a LazyVGrid rendered empty after the search shrank its data. 16 clubs need no laziness.
                            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                                ForEach(Array(Self.rows(clubs, columns: columns).enumerated()), id: \.offset) { _, row in
                                    GridRow {
                                        ForEach(row) { club in tile(club, standing: byTeam[club.id]) }
                                        ForEach(row.count..<columns, id: \.self) { _ in Color.clear.gridCellUnsizedAxes([.horizontal, .vertical]) }
                                    }
                                }
                            }
                        }
                    }
                }
                if appModel.clubs.allSatisfy({ Self.filter([$0], query: query).isEmpty }) {
                    ContentUnavailableView.search(text: query)
                }
            }
            .padding()
        }
        .background(Theme.ink)
        .navigationTitle("Clubs")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Search clubs"))
        .refreshable { await standings.load(season: appModel.season) }
        .task { if standings.state == .idle { await standings.load(season: appModel.season) } }
    }

    private func tile(_ club: Club, standing: Standing?) -> some View {
        let isFavorite = club.id == favorites.clubId
        return Button { onSelectClub(club.id) } label: {
            VStack(spacing: 8) {
                ClubLogo(club: club, size: 52)
                Text(verbatim: club.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 32)
                Text(verbatim: standing.map { "\($0.wins)–\($0.losses) · \(Format.ordinal($0.position))" } ?? " ")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(isFavorite ? Theme.lime : Theme.surface3, lineWidth: isFavorite ? 1.5 : 0.5))
            .overlay(alignment: .topTrailing) {
                if isFavorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.lime).padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: club.displayName))
        .accessibilityValue(Text(verbatim: [
            standing.map { String(localized: "\($0.wins) wins, \($0.losses) losses, \(Format.ordinal($0.position)) in the league") },
            isFavorite ? String(localized: "My club") : nil
        ].compactMap { $0 }.joined(separator: ", ")))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("clubs.tile.\(club.shortName)")
    }
}
