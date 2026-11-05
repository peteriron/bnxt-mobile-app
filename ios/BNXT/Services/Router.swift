import Foundation
import Observation

/// A screen inside a tab's navigation stack.
enum Route: Hashable, Sendable {
    case club(id: Int)
    case game(id: Int)
    /// Players are addressed by roster id: the id the game-log endpoint takes (docs/bnxt-api.md).
    case player(rosterId: Int)
    /// Compare players (§3.7); `rosterId` pre-fills slot A.
    case compare(rosterId: Int?)
    /// Players and clubs (§3.8), from Home's header.
    case search
    #if DEBUG
    case componentGallery
    #endif
}

/// `bnxt://club/537`, `bnxt://game/11323`, `bnxt://player/11173` (REQUIREMENTS §7.27).
enum DeepLink {
    static let scheme = "bnxt"

    /// The tab and route a link opens, or nil if it isn't one of ours.
    static func parse(_ url: URL) -> (tab: AppTab, route: Route)? {
        guard url.scheme?.lowercased() == scheme, let host = url.host()?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        #if DEBUG
        if host == "debug", parts == ["gallery"] { return (.home, .componentGallery) }
        #endif
        guard parts.count == 1, let id = Int(parts[0]), id > 0 else { return nil }
        switch host {
        case "club": return (.clubs, .club(id: id))
        case "game": return (.games, .game(id: id))
        case "player": return (.clubs, .player(rosterId: id))
        default: return nil
        }
    }

    static func url(for route: Route) -> URL? {
        switch route {
        case let .club(id): URL(string: "\(scheme)://club/\(id)")
        case let .game(id): URL(string: "\(scheme)://game/\(id)")
        case let .player(rosterId): URL(string: "\(scheme)://player/\(rosterId)")
        case .compare, .search: nil // not linkable (§7.27)
        #if DEBUG
        case .componentGallery: URL(string: "\(scheme)://debug/gallery")
        #endif
        }
    }
}

/// The selected tab and one navigation path per tab (REQUIREMENTS §7.2).
@MainActor @Observable
final class Router {
    var selectedTab: AppTab = .home
    var paths: [AppTab: [Route]] = [:]

    func path(for tab: AppTab) -> [Route] { paths[tab] ?? [] }

    func setPath(_ path: [Route], for tab: AppTab) { paths[tab] = path }

    /// Pushes onto the current tab's stack.
    func push(_ route: Route) {
        paths[selectedTab, default: []].append(route)
    }

    /// Opens a deep link: switches tab and shows the route on a fresh stack. Returns false for unknown links.
    @discardableResult
    func open(_ url: URL) -> Bool {
        guard let (tab, route) = DeepLink.parse(url) else { return false }
        selectedTab = tab
        paths[tab] = [route]
        return true
    }

    /// Tapping the selected tab again pops to its root (iOS convention).
    func reselect(_ tab: AppTab) {
        if tab == selectedTab { paths[tab] = [] }
        selectedTab = tab
    }
}
