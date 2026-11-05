import SwiftUI

/// What each `Route` shows. Phase 3 replaces the placeholders with the real screens.
struct RouteDestination: View {
    let route: Route
    let appModel: AppModel

    var body: some View {
        switch route {
        case let .club(id):
            ClubPlaceholderScreen(club: appModel.club(id: id), id: id)
        case let .game(id):
            PlaceholderScreen(title: "Game")
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen.game.\(id)")
        case let .player(rosterId):
            PlaceholderScreen(title: "Player")
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("screen.player.\(rosterId)")
        #if DEBUG
        case .componentGallery:
            ComponentGallery(appModel: appModel)
        #endif
        }
    }
}

/// The club hero from the prototype (`.ch`), until the club page lands in Phase 3.
private struct ClubPlaceholderScreen: View {
    let club: Club?
    let id: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ClubLogo(club: club, size: 76)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: club?.displayName ?? "#\(id)")
                            .font(Theme.display(.title2))
                            .foregroundStyle(Theme.textPrimary)
                        if let city = club?.city {
                            Text(verbatim: city).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                        if let official = club?.officialName, official != club?.displayName {
                            Text(verbatim: official).font(.caption).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                Text("The club page is coming soon.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background {
            LinearGradient(colors: [(club?.graphicColor ?? .violet).color.opacity(0.6), Theme.ink], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
        .navigationTitle(Text(verbatim: club?.displayName ?? ""))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.club.\(id)")
    }
}
