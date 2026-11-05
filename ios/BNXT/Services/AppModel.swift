import Foundation
import Observation

/// App-wide data the shell needs: the remote config and the season's clubs (REQUIREMENTS §7.24, §7.26).
/// Clubs come from the API merged with the config; if the API can't be reached and nothing is cached,
/// the config alone provides them, so onboarding always works.
@MainActor @Observable
final class AppModel {
    private(set) var config: RemoteConfig?
    private(set) var clubs: [Club] = []
    /// Where `clubs` came from: `.network`, `.cache`, or `.bundled` (config only, no logos).
    private(set) var clubsSource: Fetched<[Team]>.Source?
    private(set) var isLoading = false

    @ObservationIgnored private let api: BNXTAPIClient
    @ObservationIgnored private let configClient: RemoteConfigClient

    init(api: BNXTAPIClient = BNXTAPIClient(), configClient: RemoteConfigClient = RemoteConfigClient(),
         config: RemoteConfig? = RemoteConfig.bundled()) {
        self.api = api
        self.configClient = configClient
        self.config = config
        // Usable before the first load: config-only clubs.
        clubs = Club.merge(teams: [], config: config)
        clubsSource = clubs.isEmpty ? nil : .bundled
    }

    func club(id: Int?) -> Club? {
        guard let id else { return nil }
        return clubs.first { $0.id == id }
    }

    /// Clubs grouped for pickers: Belgium first, then the Netherlands; unknown country last.
    var clubsByCountry: [(country: Country?, clubs: [Club])] {
        let order: [Country?] = [.belgium, .netherlands, nil]
        return order.compactMap { country in
            let group = clubs.filter { $0.country == country }
            return group.isEmpty ? nil : (country, group)
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let fetched = await configClient.load() { config = fetched.value }
        let competitionId = config?.season?.competitionId ?? Season.current.competitionId
        if let teams = try? await api.teams(competitionId: competitionId), !teams.value.isEmpty {
            clubs = Club.merge(teams: teams.value, config: config)
            clubsSource = teams.source
        } else {
            clubs = Club.merge(teams: [], config: config)
            clubsSource = clubs.isEmpty ? nil : .bundled
        }
    }
}
