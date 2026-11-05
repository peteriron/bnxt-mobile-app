import SwiftUI

/// What each `Route` shows.
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
            GameScreen(gameId: id, appModel: appModel, onSelect: onSelect)
        case let .player(rosterId):
            PlayerScreen(rosterId: rosterId, appModel: appModel, onSelect: onSelect)
        case let .compare(rosterId):
            CompareScreen(presetRosterId: rosterId, appModel: appModel, favorites: favorites, onSelect: onSelect)
        #if DEBUG
        case .componentGallery:
            ComponentGallery(appModel: appModel)
        #endif
        }
    }
}
