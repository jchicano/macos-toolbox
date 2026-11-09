// SPDX-License-Identifier: MIT
// Pure auto-close state machine. The tap feature feeds it key data and posts
// what the returned action says. Testable with an injected clock.

import Foundation

/// Modifier keys relevant to pairing. Option/Alt is allowed (Spanish ISO
/// brackets arrive as Option combos); Command/Control always pass through.
public struct KeyModifiers: OptionSet, Equatable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let alternate = KeyModifiers(rawValue: 1 << 2)
    public static let shift = KeyModifiers(rawValue: 1 << 3)

    public static let none: KeyModifiers = []
}

/// Hardware keycodes (ANSI/USB HID usage, layout-independent).
public enum SpecialKey {
    public static let tab: UInt16 = 48
    public static let backspace: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let `return`: UInt16 = 36
    public static let enter: UInt16 = 76
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
    public static let home: UInt16 = 115
    public static let end: UInt16 = 119
    public static let pageUp: UInt16 = 116
    public static let pageDown: UInt16 = 121
}

public enum AutoCloseAction: Equatable {
    /// Let the keystroke through untouched.
    case pass
    /// Type opener+closer, then move left (cursor between the pair).
    case insertPair(open: String, close: String)
    /// Move right out of the pending closer.
    case tabOut
    /// Typed the pending closer itself: move right instead of duplicating.
    case overtype
    /// Delete just-inserted pair: backspace plus forward delete.
    case deletePair
}

public struct AutoCloseEngine {
    public var pairs: [Character: Character]
    public var tabOutEnabled: Bool
    public var overtypeEnabled: Bool
    public var deletePairEnabled: Bool
    public var smartQuotesEnabled: Bool

    private var pending: [Character] = []
    private var lastTyped = RingBuffer<Character>(capacity: 8)
    private var justInserted = false
    private var lastEventAt: Date?
    private let clock: Clock

    /// Idle gap after which all state is dropped.
    public var timeout: TimeInterval = 30
    /// Safety cap for pathological nesting.
    public var maxDepth = 64

    private static let symmetricQuotes: Set<Character> = ["\"", "'", "`"]

    public init(
        pairs: [Pair],
        tabOut: Bool = true,
        overtype: Bool = true,
        deletePair: Bool = true,
        smartQuotes: Bool = true,
        clock: Clock = SystemClock()
    ) {
        var table: [Character: Character] = [:]
        for pair in pairs where pair.enabled {
            if let open = pair.open.first, let close = pair.close.first {
                table[open] = close
            }
        }
        self.pairs = table
        tabOutEnabled = tabOut
        overtypeEnabled = overtype
        deletePairEnabled = deletePair
        smartQuotesEnabled = smartQuotes
        self.clock = clock
    }

    public var depth: Int { pending.count }

    /// Drops all pending closers and context.
    public mutating func invalidate() {
        pending.removeAll()
        lastTyped.clear()
        justInserted = false
    }

    /// Feeds one keyDown. `chars` is the resolved Unicode string ("" for dead keys).
    public mutating func onKey(keyCode: UInt16, chars: String, modifiers: KeyModifiers, now: Date? = nil) -> AutoCloseAction {
        let now = now ?? clock.now
        defer { lastEventAt = now }
        if let lastEventAt, now.timeIntervalSince(lastEventAt) > timeout {
            invalidate()
        }
        if modifiers.contains(.command) || modifiers.contains(.control) {
            invalidate()
            return .pass
        }
        switch keyCode {
        case SpecialKey.leftArrow, SpecialKey.rightArrow, SpecialKey.upArrow, SpecialKey.downArrow,
             SpecialKey.escape, SpecialKey.return, SpecialKey.enter,
             SpecialKey.home, SpecialKey.end, SpecialKey.pageUp, SpecialKey.pageDown:
            invalidate()
            return .pass
        case SpecialKey.tab:
            if modifiers.isEmpty, tabOutEnabled, !pending.isEmpty {
                pending.removeLast()
                justInserted = false
                return .tabOut
            }
            invalidate()
            return .pass
        case SpecialKey.backspace:
            if deletePairEnabled, justInserted, !pending.isEmpty {
                pending.removeLast()
                justInserted = false
                return .deletePair
            }
            justInserted = false
            return .pass
        default:
            break
        }
        guard chars.count == 1, let char = chars.first else {
            // Dead keys ("") or multi-char input (IME): never touch.
            return .pass
        }
        if overtypeEnabled, pending.last == char {
            pending.removeLast()
            lastTyped.push(char)
            return .overtype
        }
        if let close = pairs[char], shouldPair(char) {
            guard pending.count < maxDepth else {
                invalidate()
                return .pass
            }
            pending.append(close)
            justInserted = true
            lastTyped.push(char)
            return .insertPair(open: String(char), close: String(close))
        }
        justInserted = false
        lastTyped.push(char)
        return .pass
    }

    private func shouldPair(_ char: Character) -> Bool {
        guard smartQuotesEnabled, Self.symmetricQuotes.contains(char) else { return true }
        guard let prev = lastTyped.last else { return true }
        return !(prev.isLetter || prev.isWholeNumber)
    }
}
