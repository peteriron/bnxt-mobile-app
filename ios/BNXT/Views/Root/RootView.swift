import SwiftUI

/// The five tabs (REQUIREMENTS.md §7.2). Order matters: UI tests address tabs by index.
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home, games, standings, stats, clubs

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .home: "Home"
        case .games: "Games"
        case .standings: "Standings"
        case .stats: "Stats"
        case .clubs: "Clubs"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .games: "basketball.fill"
        case .standings: "chart.bar.fill"
        case .stats: "chart.line.uptrend.xyaxis"
        case .clubs: "shield.fill"
        }
    }
}

struct RootView: View {
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        PlaceholderScreen(title: tab.title)
                            .accessibilityElement(children: .contain) // identifier must not leak onto children
                            .accessibilityIdentifier("screen.\(tab.rawValue)")
                    }
                }
            }
        }
    }
}

#Preview {
    RootView().preferredColorScheme(.dark)
}
