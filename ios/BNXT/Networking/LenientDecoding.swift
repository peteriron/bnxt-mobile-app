import Foundation

// Lenient decoding (playbook 02, "Decode leniently where the API is sloppy"): one unexpected null or
// changed type must not abort a whole list or object. Quirks seen live are in docs/bnxt-api.md.

/// The API's `{ "data": … }` wrapper.
struct Envelope<Payload: Decodable>: Decodable {
    let data: Payload
}

/// Decodes an array, skipping elements that fail instead of failing the whole array.
struct LossyArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                _ = try? container.decode(Skip.self) // advance past the bad element
            }
        }
        self.elements = elements
    }

    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

extension KeyedDecodingContainer {
    /// The value, or nil when the key is missing, null, or of an unexpected type.
    func lenient<T: Decodable>(_ type: T.Type, forKey key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }

    /// An array with bad elements dropped; empty when the key is missing, null, or not an array.
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        lenient(LossyArray<T>.self, forKey: key)?.elements ?? []
    }

    /// A number sent as an int, a float or a numeric string.
    func number(forKey key: Key) -> Double? {
        if let value = lenient(Double.self, forKey: key) { return value }
        if let text = lenient(String.self, forKey: key) { return Double(text.trimmingCharacters(in: .whitespaces)) }
        return nil
    }

    /// An integer sent as an int, a float or a numeric string.
    func integer(forKey key: Key) -> Int? {
        number(forKey: key).map { Int($0.rounded()) }
    }

    /// Text sent as a string or a number (jerseys: a string in rosters, an int in box scores). Empty becomes nil.
    func text(forKey key: Key) -> String? {
        if let value = lenient(String.self, forKey: key) {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let value = lenient(Int.self, forKey: key) { return String(value) }
        return nil
    }

    /// A URL from a string; nil when missing, empty or malformed.
    func url(forKey key: Key) -> URL? {
        text(forKey: key).flatMap { URL(string: $0) }
    }

    /// A required integer: throws so that the enclosing element is dropped by `LossyArray`.
    func requiredInteger(forKey key: Key) throws -> Int {
        guard let value = integer(forKey: key) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing or non-numeric \(key.stringValue)"))
        }
        return value
    }

    /// A required, non-empty string.
    func requiredText(forKey key: Key) throws -> String {
        guard let value = text(forKey: key) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing \(key.stringValue)"))
        }
        return value
    }
}
