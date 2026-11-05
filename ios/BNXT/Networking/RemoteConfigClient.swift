import Foundation

/// Loads the remote config (REQUIREMENTS §7.24): network, else the last cached copy, else the copy bundled
/// into the build. It never throws, so the app always has a config.
struct RemoteConfigClient: Sendable {
    static let defaultURL = URL(string: "https://raw.githubusercontent.com/peteriron/bnxt-mobile-app/main/config/v1/config.json")!
    static let cacheKey = "remote-config/v1"

    let url: URL
    let session: URLSession
    let cache: ResponseCache?
    let bundled: @Sendable () -> RemoteConfig?
    let now: @Sendable () -> Date

    init(url: URL = Self.defaultURL, session: URLSession = .shared, cache: ResponseCache? = .default,
         bundled: @escaping @Sendable () -> RemoteConfig? = { RemoteConfig.bundled() },
         now: @escaping @Sendable () -> Date = Date.init) {
        self.url = url
        self.session = session
        self.cache = cache
        self.bundled = bundled
        self.now = now
    }

    /// nil only if the network, the cache and the bundle all fail (a broken build).
    func load() async -> Fetched<RemoteConfig>? {
        if let fresh = await fetchFromNetwork() { return fresh }
        if let entry = cache?.read(Self.cacheKey), let config = try? JSONDecoder().decode(RemoteConfig.self, from: entry.data) {
            return Fetched(value: config, source: .cache, fetchedAt: entry.storedAt)
        }
        return bundled().map { Fetched(value: $0, source: .bundled, fetchedAt: now()) }
    }

    private func fetchFromNetwork() async -> Fetched<RemoteConfig>? {
        // The CDN caches for a few minutes; don't let URLCache add more.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let config = try? JSONDecoder().decode(RemoteConfig.self, from: data)
        else { return nil }
        let fetchedAt = now()
        cache?.write(data, for: Self.cacheKey, at: fetchedAt)
        return Fetched(value: config, source: .network, fetchedAt: fetchedAt)
    }
}

extension RemoteConfigClient: VersionPolicySource {
    func currentPolicy() async -> PolicySnapshot? {
        await load().map { PolicySnapshot(policy: $0.value.versionPolicy, minimumDataSchema: $0.value.minimumDataSchema) }
    }
}
