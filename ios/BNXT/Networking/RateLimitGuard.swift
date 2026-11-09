import Foundation

/// Our own brakes on BNXT's rate limit (docs/bnxt-api.md "Polling policy"): 200 requests per ~65 s, counted per client IP,
/// so a busy venue's Wi-Fi shares it. While holding off, the client answers from the cache instead of the network.
///
/// - Below `lowWater` requests left, hold off until the window has reset.
/// - After a 429, hold off for its `Retry-After`; after a 5xx, for 5 s, doubling up to `maxBackoff`. A success resets this.
///
/// One instance is shared by every copy of `BNXTAPIClient` (a struct), so all screens see the same state.
final class RateLimitGuard: @unchecked Sendable {
    static let lowWater = 20
    static let window: TimeInterval = 65
    static let firstBackoff: TimeInterval = 5
    static let maxBackoff: TimeInterval = 60

    private let lock = NSLock()
    private var lowSince: Date?
    private var backoffUntil: Date?
    private var serverFailures = 0

    /// When the network may be asked again, or nil if it may be asked now. `inBackoff` tells a back-off
    /// (fail fast without a cache) from merely running low (still ask when nothing is cached).
    func holdUntil(at now: Date) -> (until: Date, inBackoff: Bool)? {
        lock.withLock {
            if let backoffUntil, now < backoffUntil { return (backoffUntil, true) }
            if let lowSince, now.timeIntervalSince(lowSince) < Self.window { return (lowSince + Self.window, false) }
            return nil
        }
    }

    /// Every HTTP response: what `X-RateLimit-Remaining` says, and how the request went.
    func record(status: Int, remaining: Int?, retryAfter: TimeInterval?, at now: Date) {
        lock.withLock {
            if let remaining { lowSince = remaining < Self.lowWater ? now : nil }
            switch status {
            case 200..<300:
                serverFailures = 0
                backoffUntil = nil
            case 429:
                backoffUntil = now + (retryAfter ?? Self.backoff(after: serverFailures))
                serverFailures += 1
            case 500..<600:
                backoffUntil = now + Self.backoff(after: serverFailures)
                serverFailures += 1
            default:
                break
            }
        }
    }

    /// 5, 10, 20, 40, 60, 60… seconds.
    static func backoff(after failures: Int) -> TimeInterval {
        min(firstBackoff * pow(2, Double(failures)), maxBackoff)
    }
}
