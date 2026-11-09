import SwiftUI

/// First launch (REQUIREMENTS §3.1): a splash, then "Pick your club". Finishes by choosing a favourite club.
struct OnboardingView: View {
    let appModel: AppModel
    let onFinish: (Club) -> Void

    @State private var step = Step.welcome
    @State private var selection: Club?

    enum Step { case welcome, pickClub }

    var body: some View {
        ZStack {
            Theme.ink.ignoresSafeArea()
            switch step {
            case .welcome: welcome
            case .pickClub: picker
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding")
    }

    private var welcome: some View {
        // Scrolls only when the text is too large to fit.
        ViewThatFits(in: .vertical) {
            welcomeContent
            ScrollView { welcomeContent }
        }
    }

    private var welcomeContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: "BNXT")
                    .font(.custom(DisplayFace.headline.rawValue, size: 88, relativeTo: .largeTitle))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: "LEAGUE")
                    .font(.custom(DisplayFace.headline.rawValue, size: 36, relativeTo: .title))
                    .foregroundStyle(Theme.lime)
            }
            // The wordmark is a logo: it grows a little with the text size, never past the screen.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text("Belgium and the Netherlands, 16 clubs, one league. Live scores, box scores and stats for every game.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            Button {
                withAnimation { step = .pickClub }
            } label: {
                Text("Get started").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.lime)
            .foregroundStyle(Theme.ink)
            .accessibilityIdentifier("onboarding.start")
        }
        .padding(24)
        .background {
            RadialGradient(colors: [Theme.violet.opacity(0.55), .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
                .ignoresSafeArea()
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The title scrolls with the clubs, so large text never squeezes the list out.
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick your club")
                        .font(Theme.display(.title))
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Text("Home will show your club's games, standing and leaders. You can change it any time.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top], 20)
                ClubPickerGrid(appModel: appModel, selection: selection) { selection = $0 }
                    .padding(.bottom, 110)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if let selection { onFinish(selection) }
            } label: {
                Group {
                    if let selection {
                        Text("Follow \(selection.displayName)")
                    } else {
                        Text("Choose a club to continue")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.violet)
            .disabled(selection == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .background(LinearGradient(colors: [.clear, Theme.ink], startPoint: .top, endPoint: .center).ignoresSafeArea())
            .accessibilityIdentifier("onboarding.follow")
        }
    }
}

/// Clubs in a 3-column grid per country; used by onboarding and Settings.
struct ClubPickerGrid: View {
    let appModel: AppModel
    let selection: Club?
    let onSelect: (Club) -> Void

    @ScaledMetric(relativeTo: .body) private var tileWidth: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(appModel.clubsByCountry, id: \.country) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.country.map(Self.countryTitle) ?? String(localized: "Other"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 10)], spacing: 10) {
                        ForEach(group.clubs) { club in tile(club) }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    static func countryTitle(_ country: Country) -> String {
        switch country {
        case .belgium: "🇧🇪 " + String(localized: "Belgium")
        case .netherlands: "🇳🇱 " + String(localized: "Netherlands")
        }
    }

    private func tile(_ club: Club) -> some View {
        let selected = club.id == selection?.id
        return Button { onSelect(club) } label: {
            VStack(spacing: 8) {
                ClubLogo(club: club, size: 48)
                Text(verbatim: club.displayName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(minHeight: 32)
                if let city = club.city {
                    Text(verbatim: city).font(.caption).foregroundStyle(Theme.textTertiary).lineLimit(1)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? Theme.lime : Theme.surface3, lineWidth: selected ? 2 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("club.\(club.shortName)")
    }
}
