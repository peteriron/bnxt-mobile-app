import EventKit
import EventKitUI
import SwiftUI

/// Preview tab for upcoming games (§3.4): season so far, last-5 form, players to watch, tickets, calendar,
/// earlier meetings.
struct GamePreview: View {
    let model: GameViewModel
    let game: Game
    let club: (Team) -> Club
    let onSelect: (Route) -> Void

    @State private var addingToCalendar = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var large: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        let home = club(game.home.team), away = club(game.away.team)
        VStack(alignment: .leading, spacing: 18) {
            seasonTable(home: home, away: away)
            playersToWatch(home: home, away: away)
            actions(home: home, away: away)
            let earlier = model.earlierMeetings
            if !earlier.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Earlier this season")
                    ForEach(earlier) { meeting in
                        Button { onSelect(.game(id: meeting.id)) } label: {
                            GameRow(game: meeting, home: club(meeting.home.team), away: club(meeting.away.team),
                                    subtitle: Format.relativeDay(meeting.tipOff, now: .now))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("game.earlierMeetings")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.preview")
        .sheet(isPresented: $addingToCalendar) {
            CalendarEventEditor(event: CalendarEventDraft(game: game, home: home, away: away)) { addingToCalendar = false }
                .ignoresSafeArea()
        }
    }

    private func previewRows(home: Club, away: Club) -> [PreviewRow] {
        let homeStanding = model.standings[home.id], awayStanding = model.standings[away.id]
        let homeForm = model.teamForm(teamId: home.id), awayForm = model.teamForm(teamId: away.id)
        return [
            PreviewRow(title: "Record", home: homeStanding.map { "\($0.wins)–\($0.losses)" } ?? "–",
                       away: awayStanding.map { "\($0.wins)–\($0.losses)" } ?? "–"),
            PreviewRow(title: "Position", home: homeStanding.map { Format.ordinal($0.position) } ?? "–",
                       away: awayStanding.map { Format.ordinal($0.position) } ?? "–"),
            PreviewRow(title: "Points per game", home: Self.average(homeForm.pointsFor), away: Self.average(awayForm.pointsFor)),
            PreviewRow(title: "Points allowed", home: Self.average(homeForm.pointsAgainst), away: Self.average(awayForm.pointsAgainst)),
            PreviewRow(title: "Rebounds", home: Self.average(homeForm.rebounds), away: Self.average(awayForm.rebounds)),
            PreviewRow(title: "Assists", home: Self.average(homeForm.assists), away: Self.average(awayForm.assists)),
            PreviewRow(title: "FG%", home: Self.average(homeForm.fieldGoalPercentage), away: Self.average(awayForm.fieldGoalPercentage)),
            PreviewRow(title: "3P%", home: Self.average(homeForm.threePointPercentage), away: Self.average(awayForm.threePointPercentage))
        ]
    }

    private func seasonTable(home: Club, away: Club) -> some View {
        let rows = previewRows(home: home, away: away)
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Season so far")
            VStack(spacing: 0) {
                HStack {
                    ClubLogo(club: home, size: 24)
                    Spacer()
                    ClubLogo(club: away, size: 24)
                }
                .padding(.vertical, 10)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    let title = Text(row.title).font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                    VStack(spacing: 2) {
                        // At accessibility sizes the title gets its own line; between the numbers it wrapped per syllable.
                        if large { title.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6) }
                        HStack {
                            Text(verbatim: row.home).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if !large { title; Spacer() }
                            Text(verbatim: row.away).fontWeight(.bold).foregroundStyle(Theme.textPrimary)
                        }
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(minHeight: 34)
                    .accessibilityElement(children: .combine)
                }
                let lastFive = Text("Last 5").font(.caption.weight(.semibold)).foregroundStyle(Theme.textTertiary)
                VStack(spacing: 2) {
                    if large { lastFive.frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6) }
                    HStack {
                        FormStrip(wins: model.form(teamId: home.id))
                        Spacer()
                        if !large { lastFive; Spacer() }
                        FormStrip(wins: model.form(teamId: away.id))
                    }
                }
                .frame(minHeight: 40)
            }
            .padding(.horizontal, 14)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("game.seasonSoFar")
        }
    }

    private struct PreviewRow {
        let title: LocalizedStringKey
        let home: String
        let away: String
    }

    private static func average(_ value: Double?) -> String { value.map(Format.average) ?? "–" }

    private func playersToWatch(home: Club, away: Club) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Players to watch")
            AdaptiveStack(spacing: 10) {
                watch(GameDetail.playerToWatch(model.players[home.id] ?? []), club: home)
                watch(GameDetail.playerToWatch(model.players[away.id] ?? []), club: away)
            }
        }
    }

    @ViewBuilder
    private func watch(_ player: PlayerSeasonAverages?, club: Club) -> some View {
        if let player {
            Button { onSelect(.player(rosterId: player.rosterId)) } label: {
                VStack(spacing: 8) {
                    PlayerAvatar(player: player.player, size: 64)
                    Text(verbatim: player.player.fullName)
                        .font(.subheadline.weight(.bold)).foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center).lineLimit(2)
                    Text(verbatim: club.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                    Text(verbatim: "\(Format.average(player.perGame.points)) PTS · \(Format.average(player.perGame.rebounds)) REB · "
                        + "\(Format.average(player.perGame.efficiency)) VAL")
                        .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("game.playerToWatch.\(club.shortName)")
        } else {
            Color.clear.frame(maxWidth: .infinity)
        }
    }

    private func actions(home: Club, away: Club) -> some View {
        AdaptiveStack(spacing: 10) {
            if let url = home.ticketURL {
                Link(destination: url) { Label("Tickets", systemImage: "ticket").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.violet)
                    .accessibilityIdentifier("game.tickets")
            }
            Button { addingToCalendar = true } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Theme.textPrimary)
            .accessibilityIdentifier("game.addToCalendar")
        }
        .controlSize(.large)
    }
}

/// Info tab (§3.4): date and tip-off, arena, where to watch, tickets (not for finished games), official report.
struct GameInfo: View {
    let game: Game
    let home: Club

    var body: some View {
        VStack(spacing: 0) {
            row(icon: "calendar", title: Text(verbatim: Format.longDate(game.tipOff)),
                detail: Text("Tip-off \(Format.tipOffTime(game.tipOff)) (\(GameDetail.zoneAbbreviation(at: game.tipOff)))"))
            divider
            row(icon: "mappin.and.ellipse", title: Text(verbatim: game.arena ?? String(localized: "Arena to be confirmed")),
                detail: Text(verbatim: [home.city, home.country.map(Self.countryName)].compactMap { $0 }.joined(separator: ", ")))
            if let url = GameDetail.watchURL {
                divider
                link(url, icon: "tv", title: Text("Where to watch"), detail: Text("Live and on demand on BNXT.tv"), id: "game.info.watch")
            }
            if game.status != .finished, let url = home.ticketURL {
                divider
                link(url, icon: "ticket", title: Text("Tickets"), detail: Text("Sold by \(home.displayName)"), id: "game.info.tickets")
            }
            if let url = GameDetail.reportURL(gameId: game.id) {
                divider
                link(url, icon: "globe", title: Text("Game report on bnxtleague.com"), detail: Text("Official page for this game"),
                     id: "game.info.report")
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.info")
    }

    private static func countryName(_ country: Country) -> String {
        switch country {
        case .belgium: String(localized: "Belgium")
        case .netherlands: String(localized: "Netherlands")
        }
    }

    private var divider: some View { Divider().overlay(Theme.surface3).padding(.leading, 54) }

    private func row(icon: String, title: Text, detail: Text) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.body).foregroundStyle(Theme.violetHigh).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                detail.font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private func link(_ url: URL, icon: String, title: Text, detail: Text, id: String) -> some View {
        Link(destination: url) {
            HStack {
                row(icon: icon, title: title, detail: detail)
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textTertiary).padding(.trailing, 14)
            }
        }
        .accessibilityIdentifier(id)
    }
}

// MARK: - Calendar

/// What goes into the calendar event, as plain values so it's testable.
struct CalendarEventDraft: Equatable {
    let title: String
    let start: Date
    let end: Date
    let location: String?
    let url: URL?

    /// A game lasts about two hours.
    init(game: Game, home: Club, away: Club) {
        title = "\(home.displayName) – \(away.displayName)"
        start = game.tipOff
        end = game.tipOff.addingTimeInterval(2 * 3600)
        location = [game.arena, home.city].compactMap { $0 }.joined(separator: ", ").nilIfEmpty
        url = GameDetail.reportURL(gameId: game.id)
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

/// The system's event editor. On iOS 17+ it runs out of process and needs no calendar permission:
/// the app never reads the user's calendar (§7.16).
private struct CalendarEventEditor: UIViewControllerRepresentable {
    let event: CalendarEventDraft
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let calendarEvent = EKEvent(eventStore: store)
        calendarEvent.title = event.title
        calendarEvent.startDate = event.start
        calendarEvent.endDate = event.end
        calendarEvent.location = event.location
        calendarEvent.url = event.url
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = calendarEvent
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onFinish: () -> Void
        init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onFinish()
        }
    }
}
