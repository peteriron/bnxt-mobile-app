#if DEBUG
import SwiftUI

/// Every design-system component with sample data, for review on a real screen (playbook 03, "Look at the screens").
/// Debug builds only: `bnxt://debug/gallery` or `--uitest-open bnxt://debug/gallery`.
struct ComponentGallery: View {
    let appModel: AppModel
    @State private var chip = "all"

    private var spirou: Club? { appModel.club(id: 537) }
    private var oostende: Club? { appModel.club(id: 539) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                group("Club logos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(appModel.clubs) { club in ClubLogo(club: club, size: 44) }
                        }
                    }
                }
                group("Game rows") {
                    VStack(spacing: 0) {
                        ForEach(SampleData.games) { game in
                            GameRow(game: game, home: appModel.club(id: game.home.team.id), away: appModel.club(id: game.away.team.id),
                                    favoriteClubId: 537, subtitle: game.status == .scheduled ? "Thursday" : nil)
                            Divider().overlay(Theme.surface3)
                        }
                    }
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                group("Live card") {
                    LiveCard(game: SampleData.liveGame, home: spirou, away: oostende, lastPlay: "A. Miller buries a three (assist J. Heath)")
                }
                group("Status, form, chips") {
                    HStack(spacing: 16) {
                        StatusPill(label: .live(period: "Q3"))
                        StatusPill(label: .final)
                        StatusPill(label: .scheduled(time: "20:30"))
                        FormStrip(wins: [true, false, true, true, false])
                    }
                    ChipBar(options: [("all", "All clubs"), ("mine", "Spirou Basket")], selection: $chip)
                        .padding(.horizontal, -16)
                    SectionHeader(title: "Around the league", actionTitle: "All games") {}
                }
                group("Stat rings") {
                    HStack(spacing: 16) {
                        StatRing(title: "FG", percentage: 44.5, detail: "4.2/9.4", color: spirou?.graphicColor ?? .violet)
                        StatRing(title: "3PT", percentage: 33.3, detail: "1.0/3.0", color: spirou?.graphicColor ?? .violet)
                        StatRing(title: "FT", percentage: nil, detail: "0/0", color: spirou?.graphicColor ?? .violet)
                    }
                }
                group("Sparkline") {
                    Sparkline(values: [4, 8, 5, 13, 9], labels: ["LEU", "MEC", "BRU", "OOS", "ANT"], average: 7.8,
                              color: spirou?.graphicColor ?? .violet)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                group("Box score") {
                    BoxScoreTable(box: SampleData.boxScore)
                }
                group("Club colours, lifted to 3:1 for graphics") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                        ForEach(appModel.clubs) { club in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4).fill((club.brandColor ?? .violet).color).frame(width: 22, height: 22)
                                RoundedRectangle(cornerRadius: 4).fill(club.graphicColor.color).frame(width: 22, height: 22)
                                Text(verbatim: club.shortName).font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Theme.ink)
        .navigationTitle("Components")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("screen.gallery")
    }

    private func group(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.caption.weight(.bold)).textCase(.uppercase).foregroundStyle(Theme.textTertiary)
            content()
        }
    }
}

/// Hand-built sample models for previews and the gallery (real clubs, game 11323's numbers).
enum SampleData {
    static let spirou = Team(id: 537, name: "Val-Dieu Spirou Basket", shortName: "CHA", country: .belgium)
    static let oostende = Team(id: 539, name: "Coretec Oostende", shortName: "OOS", country: .belgium)
    static let rotterdam = Team(id: 551, name: "Zeeuw & Zeeuw Rotterdam City", shortName: "RCB", country: .netherlands)
    static let brussels = Team(id: 561, name: "Brussels Basketball", shortName: "BRU", country: .belgium)

    static func date(_ text: String) -> Date { GameTime.parse(text) ?? .now }

    static let finishedGame = Game(id: 11323, tipOff: date("2026-10-23 20:30:00"), status: .finished,
                                   home: GameSide(team: spirou, score: 65, periodScores: [21, 12, 12, 20]),
                                   away: GameSide(team: oostende, score: 70, periodScores: [14, 18, 23, 15]),
                                   period: "Q4", arena: "Dôme")
    static let liveGame = Game(id: 1, tipOff: date("2026-11-05 20:30:00"), status: .inProgress(raw: "live"),
                               home: GameSide(team: spirou, score: 49, periodScores: [21, 16, 12]),
                               away: GameSide(team: oostende, score: 61, periodScores: [23, 20, 18]),
                               period: "Q3")
    static let upcomingGame = Game(id: 11351, tipOff: date("2026-11-05 20:30:00"), status: .scheduled,
                                   home: GameSide(team: spirou, score: nil, periodScores: []),
                                   away: GameSide(team: rotterdam, score: nil, periodScores: []), arena: "Dôme")
    static let plateGame = Game(id: 2, tipOff: date("2026-10-31 20:30:00"), status: .finished,
                                home: GameSide(team: brussels, score: 81, periodScores: []),
                                away: GameSide(team: rotterdam, score: 74, periodScores: []))

    static let games: [Game] = [liveGame, finishedGame, plateGame, upcomingGame]

    static let boxScore: TeamBoxScore = {
        func line(_ roster: Int, _ name: (first: String, last: String), jersey: String, starter: Bool,
                  _ configure: (inout StatLine) -> Void) -> PlayerBoxLine {
            var stats = StatLine()
            configure(&stats)
            stats.efficiency = stats.points + stats.rebounds + stats.assists - (stats.fieldGoalsAttempted - stats.fieldGoalsMade)
            return PlayerBoxLine(rosterId: roster, player: Player(id: roster, firstName: name.first, lastName: name.last),
                                 isStarter: starter, jersey: jersey, stats: stats)
        }
        let lines = [
            line(1, ("Adam", "Miller"), jersey: "44", starter: true) {
                $0.minutes = 22; $0.points = 16; $0.rebounds = 3; $0.assists = 2
                $0.fieldGoalsMade = 5; $0.fieldGoalsAttempted = 9; $0.plusMinus = 13
            },
            line(2, ("Joshua", "Heath"), jersey: "3", starter: true) {
                $0.minutes = 31; $0.points = 13; $0.rebounds = 4; $0.assists = 6
                $0.fieldGoalsMade = 5; $0.fieldGoalsAttempted = 11; $0.plusMinus = 4
            },
            line(3, ("Douglas", "Konieczny Jr"), jersey: "22", starter: false) {
                $0.minutes = 18; $0.points = 9; $0.rebounds = 2; $0.assists = 1
                $0.fieldGoalsMade = 3; $0.fieldGoalsAttempted = 8; $0.plusMinus = -5
            }
        ]
        var totals = StatLine()
        totals.points = 70
        totals.rebounds = 36
        totals.assists = 14
        totals.steals = 9
        totals.fieldGoalsMade = 23
        totals.fieldGoalsAttempted = 56
        totals.efficiency = 93
        return TeamBoxScore(team: oostende, isHome: false, players: lines, totals: totals)
    }()
}
#endif
