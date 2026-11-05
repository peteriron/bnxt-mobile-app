import Foundation

/// A value plus where it came from, so screens can show "last updated" when it's from the cache.
struct Fetched<Value: Sendable>: Sendable {
    /// `.cache`: the network failed and a cached copy was served instead (show "Offline · updated …").
    /// `.stored`: a cached copy served on purpose, without asking the network (an immutable finished game, or a copy
    /// younger than `.maxAge`). Not offline, so no note.
    /// `.bundled`: shipped inside the app (remote config's offline fallback).
    enum Source: Sendable, Equatable { case network, cache, stored, bundled }

    let value: Value
    let source: Source
    let fetchedAt: Date

    var isFromCache: Bool { source != .network }
    /// The network failed and this is the best we had: screens say they're offline.
    var isFallback: Bool { source == .cache || source == .bundled }
}

/// The BNXT League API client: one method per endpoint (docs/bnxt-api.md), returning decoded models.
///
/// - Every successful response is cached (never-decode fields stripped first, §7.16). On any failure the
///   cached copy is served instead, marked `.cache`; with nothing cached the error is thrown. Deliberate cache hits
///   (`.cacheFirst`, `.maxAge`) are marked `.stored`.
/// - Immutable data (a finished game's box score) is served cache-first without a request. An empty
///   cached result isn't trusted, because it may still be filled in later.
/// - Dependencies are injected (playbook 02): tests pass a `MockURLProtocol` session, a temp-directory
///   cache and a fixed clock.
struct BNXTAPIClient: Sendable {
    enum CachePolicy: Sendable {
        /// Ask the network; fall back to the cache on failure.
        case networkFirst
        /// Use a usable cached copy without a request; otherwise behave like `.networkFirst`.
        case cacheFirst
        /// Use a usable cached copy younger than this without a request; otherwise behave like `.networkFirst`.
        /// For big responses that change only after game nights (the leaders are 1.4 MB and take ~10 s).
        case maxAge(TimeInterval)
    }

    let configuration: APIConfiguration?
    let session: URLSession
    let cache: ResponseCache?
    let now: @Sendable () -> Date
    /// The website sends `?lang=` and `X-Localization`; NL/FR come later (§7.11).
    let language: String

    init(configuration: APIConfiguration? = .main, session: URLSession = .shared, cache: ResponseCache? = .default,
         language: String = "en", now: @escaping @Sendable () -> Date = Date.init) {
        self.configuration = configuration
        self.session = session
        self.cache = cache
        self.language = language
        self.now = now
    }

    // MARK: Endpoints

    /// All clubs in a competition.
    func teams(competitionId: Int = Season.current.competitionId) async throws -> Fetched<[Team]> {
        try await list(Endpoint("competition-team/all", ["competition_id": "\(competitionId)"]), of: Team.self)
    }

    /// One club, including its season averages (`statistics`).
    func team(id: Int) async throws -> Fetched<Team> {
        try await fetch(Endpoint("competition-team/find/\(id)"), as: Envelope<Team>.self) { $0.data }
    }

    func standings(competitionId: Int = Season.current.competitionId,
                   phaseId: Int = Season.current.phaseIds[0]) async throws -> Fetched<[Standing]> {
        try await list(Endpoint("standings/competition/\(competitionId)/phase/\(phaseId)"), of: Standing.self)
    }

    func roster(teamId: Int, competitionId: Int = Season.current.competitionId) async throws -> Fetched<[RosterEntry]> {
        try await list(Endpoint("roster/team-players/\(teamId)", ["competition_id": "\(competitionId)"]), of: RosterEntry.self)
    }

    /// One roster entry: the player's bio for the player page. Takes the **roster id**.
    /// (The API also sends a free-text `description`; it's never decoded or cached, §7.16.)
    func rosterEntry(id: Int) async throws -> Fetched<RosterEntry> {
        try await fetch(Endpoint("roster/find/\(id)"), as: Envelope<RosterEntry>.self) { $0.data }
    }

    /// Per-game season averages for every player of a club.
    func playerAverages(teamId: Int) async throws -> Fetched<[PlayerSeasonAverages]> {
        try await list(Endpoint("competition-team/player-averages/\(teamId)"), of: PlayerSeasonAverages.self)
    }

    /// A club's finished games this season.
    func teamGames(teamId: Int) async throws -> Fetched<[Game]> {
        try await list(Endpoint("competition-team/statistics-by-game/total/\(teamId)"), of: Game.self)
    }

    /// ~30 games around today, with FIBA LiveStats ids. (No trailing slash: that 301s.)
    func gameSlider(competitionId: Int = Season.current.competitionId) async throws -> Fetched<[Game]> {
        try await list(Endpoint("schedule/game-slider/\(competitionId)"), of: Game.self)
    }

    /// One game with arena and quarter scores. Pass `.cacheFirst` once the game is known to be finished.
    func game(id: Int, cachePolicy: CachePolicy = .networkFirst) async throws -> Fetched<Game> {
        try await fetch(Endpoint("schedule/find/\(id)"), as: Envelope<Game>.self, policy: cachePolicy,
                        isUsable: { $0.status == .finished }, map: { $0.data })
    }

    /// A game's box score. For a finished game it's served cache-first; an empty cached one is refetched.
    func boxScore(gameId: Int, competitionId: Int = Season.current.competitionId, isFinal: Bool) async throws -> Fetched<BoxScore> {
        try await fetch(Endpoint("boxscore/game/\(competitionId)/\(gameId)"), as: Envelope<BoxScore>.self,
                        policy: isFinal ? .cacheFirst : .networkFirst, isUsable: { !$0.isEmpty }, map: { $0.data })
    }

    /// A player's games this season. Takes the **roster id**, not the player id (docs/bnxt-api.md).
    /// An unknown roster id returns an empty list.
    func playerGameLog(rosterId: Int) async throws -> Fetched<[PlayerGameLine]> {
        try await list(Endpoint("boxscore/player/season-games/\(rosterId)"), of: PlayerGameLine.self)
    }

    /// ~1.4 MB and slow; callers on a screen pass `.maxAge` so it isn't refetched on every visit.
    func playerLeaders(competitionId: Int = Season.current.competitionId,
                       phaseId: Int = Season.current.phaseIds[0],
                       cachePolicy: CachePolicy = .networkFirst) async throws -> Fetched<PlayerLeaders> {
        try await fetch(Endpoint("player/average-rankings/\(competitionId)", ["phase_id": "\(phaseId)"]),
                        as: PlayerLeaders.self, policy: cachePolicy) { $0 }
    }

    // MARK: Plumbing

    struct Endpoint: Sendable, Equatable {
        let path: String
        let query: [String: String]

        init(_ path: String, _ query: [String: String] = [:]) {
            self.path = path
            self.query = query
        }

        /// Stable across runs and independent of the key: the path plus sorted query.
        var cacheKey: String {
            query.isEmpty ? path : path + "?" + query.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        }
    }

    private func list<Element: Decodable & Sendable>(_ endpoint: Endpoint, of _: Element.Type) async throws -> Fetched<[Element]> {
        try await fetch(endpoint, as: Envelope<LossyArray<Element>>.self) { $0.data.elements }
    }

    private func fetch<Payload: Decodable, Value: Sendable>(
        _ endpoint: Endpoint,
        as _: Payload.Type,
        policy: CachePolicy = .networkFirst,
        isUsable: (Value) -> Bool = { _ in true },
        map: (Payload) -> Value
    ) async throws -> Fetched<Value> {
        let cached = cache?.read(endpoint.cacheKey).flatMap { entry -> Fetched<Value>? in
            guard let payload = try? JSONDecoder().decode(Payload.self, from: entry.data) else { return nil }
            return Fetched(value: map(payload), source: .cache, fetchedAt: entry.storedAt)
        }
        if let cached, isUsable(cached.value) {
            let stored = Fetched(value: cached.value, source: .stored, fetchedAt: cached.fetchedAt)
            switch policy {
            case .cacheFirst: return stored
            case let .maxAge(age) where now().timeIntervalSince(cached.fetchedAt) < age: return stored
            default: break
            }
        }
        do {
            let data = try await load(endpoint)
            let payload: Payload
            do {
                payload = try JSONDecoder().decode(Payload.self, from: data)
            } catch {
                throw APIError.decoding(endpoint: endpoint.path, message: String(describing: error))
            }
            let fetchedAt = now()
            if let sanitized = PrivacyFilter.sanitized(data) {
                cache?.write(sanitized, for: endpoint.cacheKey, at: fetchedAt)
            }
            return Fetched(value: map(payload), source: .network, fetchedAt: fetchedAt)
        } catch {
            if let cached { return cached }
            throw error
        }
    }

    private func load(_ endpoint: Endpoint) async throws -> Data {
        guard let configuration else { throw APIError.missingConfiguration }
        var url = configuration.baseURL.appending(path: endpoint.path)
        let items = endpoint.query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        url.append(queryItems: items + [URLQueryItem(name: "lang", value: language)])

        var request = URLRequest(url: url, timeoutInterval: 20)
        configuration.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue(language, forHTTPHeaderField: "X-Localization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.network(error.code)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: return data
        case 401: throw APIError.unauthorized
        case 404: throw APIError.notFound
        case 429: throw APIError.rateLimited(retryAfter: http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init))
        default: throw APIError.http(status: http.statusCode)
        }
    }
}
