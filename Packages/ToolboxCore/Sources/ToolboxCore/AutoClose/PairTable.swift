// SPDX-License-Identifier: MIT
// Auto-close pair table. The engine (matching logic) lands in F5.

/// A single-character open/close pair stored as String (Character is not
/// Codable on this toolchain). Invariant: both hold exactly one character.
public struct Pair: Codable, Equatable {
    public var open: String
    public var close: String
    public var enabled: Bool

    public init(open: String, close: String, enabled: Bool) {
        self.open = open
        self.close = close
        self.enabled = enabled
    }

    /// Enabled pairs, keyed by opener.
    public func table(from pairs: [Pair]) -> [Character: Character] {
        var table: [Character: Character] = [:]
        for pair in pairs where pair.enabled {
            if let open = pair.open.first, let close = pair.close.first {
                table[open] = close
            }
        }
        return table
    }

    /// Default pairs from the plan (§6.4). `<` and curly single quotes ship disabled.
    public static let defaults: [Pair] = [
        Pair(open: "(", close: ")", enabled: true),
        Pair(open: "[", close: "]", enabled: true),
        Pair(open: "{", close: "}", enabled: true),
        Pair(open: "\"", close: "\"", enabled: true),
        Pair(open: "'", close: "'", enabled: true),
        Pair(open: "`", close: "`", enabled: true),
        Pair(open: "<", close: ">", enabled: false),
        Pair(open: "¿", close: "?", enabled: true),
        Pair(open: "¡", close: "!", enabled: true),
        Pair(open: "“", close: "”", enabled: true),
        Pair(open: "«", close: "»", enabled: true),
        Pair(open: "‘", close: "’", enabled: false),
    ]
}
