import CryptoKit
import Foundation

/// File-based cache of the last successful response per request (playbook 02, "Caching and offline").
/// One file per key in `directory`; its modification date is when the response was fetched.
/// Callers pass already-sanitized data (`PrivacyFilter`).
struct ResponseCache: Sendable {
    let directory: URL

    struct Entry: Sendable {
        let data: Data
        let storedAt: Date
    }

    /// `Caches/APIResponses`. The system may purge it; that only costs a refetch.
    static let `default`: ResponseCache? = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first
        .map { ResponseCache(directory: $0.appending(path: "APIResponses", directoryHint: .isDirectory)) }

    func read(_ key: String) -> Entry? {
        let url = fileURL(for: key)
        guard let data = try? Data(contentsOf: url),
              let date = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
        else { return nil }
        return Entry(data: data, storedAt: date)
    }

    func write(_ data: Data, for key: String, at date: Date) {
        let url = fileURL(for: key)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        } catch {
            // A failed cache write never fails the request.
        }
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Keys are request paths with queries; hashing keeps file names safe and fixed-length.
    func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appending(path: "\(digest).json")
    }
}
