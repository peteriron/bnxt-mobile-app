import SwiftUI

/// What each `Route` shows. Phase 3 replaces the placeholders with the real screens.
struct RouteDestination: View {
    let route: Route
    let appModel: AppModel
    let favorites: FavoriteClubStore
    let onSelect: (Route) -> Void

    var body: some View {
        switch route {
        case let .club(id):
            ClubScreen(clubId: id, appModel: appModel, favorites: favorites, onSelect: onSelect)
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
