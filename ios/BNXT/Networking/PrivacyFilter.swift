import Foundation

/// Removes the fields we never decode (REQUIREMENTS §7.16) from raw JSON before it's written to the response cache,
/// so the cache only ever holds what the app is allowed to hold. Applied recursively to every object.
enum PrivacyFilter {
    static let neverStoredKeys: Set<String> = ["facebook", "twitter", "instagram", "description"]

    /// The JSON without those keys, or nil if `data` isn't JSON (then it isn't cached at all).
    static func sanitized(_ data: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return try? JSONSerialization.data(withJSONObject: strip(object), options: [.fragmentsAllowed])
    }

    private static func strip(_ node: Any) -> Any {
        if let object = node as? [String: Any] {
            return object.filter { !neverStoredKeys.contains($0.key) }.mapValues(strip)
        }
        if let array = node as? [Any] {
            return array.map(strip)
        }
        return node
    }
}
