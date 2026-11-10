// SPDX-License-Identifier: MIT
// Trigger matcher: buffers recent keystrokes, fires on trigger (+delimiter).

import Foundation

/// A fired trigger: which snippet and how many characters to erase.
public struct SnippetMatch: Equatable {
    public var snippet: Snippet
    /// Characters to delete (the trigger length).
    public var triggerLength: Int
}

public struct SnippetEngine {
    public var snippets: [Snippet]
    public var expandOnDelimiter: Bool
    public var expandImmediately: Bool

    /// Longest trigger considered; caps the buffer.
    public static let maxTriggerLength = 32

    /// Delimiters that complete a trigger. ";" is excluded on purpose so
    /// ";sig" style triggers survive; so are trigger-friendly "-_".
    public static func isDelimiter(_ char: Character) -> Bool {
        char.isWhitespace || ".,:!?()[]{}<>\"'`~@#$%^&*-+=|\\/".contains(char)
    }

    private var buffer: [Character] = []

    public init(snippets: [Snippet] = [], expandOnDelimiter: Bool = true, expandImmediately: Bool = false) {
        self.snippets = snippets
        self.expandOnDelimiter = expandOnDelimiter
        self.expandImmediately = expandImmediately
    }

    /// Clears buffered keystrokes (mouse, app switch, arrows, Command...).
    public mutating func invalidate() {
        buffer.removeAll(keepingCapacity: true)
    }

    /// Feeds one typed character. Returns a match when expansion should fire.
    public mutating func input(_ char: Character) -> SnippetMatch? {
        if expandImmediately {
            push(char)
            return longestMatch()
        }
        if Self.isDelimiter(char) {
            defer { invalidate() }
            return longestMatch()
        }
        push(char)
        return nil
    }

    private mutating func push(_ char: Character) {
        buffer.append(char)
        if buffer.count > Self.maxTriggerLength {
            buffer.removeFirst(buffer.count - Self.maxTriggerLength)
        }
    }

    /// Longest enabled trigger matching the buffer suffix.
    private func longestMatch() -> SnippetMatch? {
        let enabled = snippets.filter(\.enabled).sorted { $0.trigger.count > $1.trigger.count }
        for snippet in enabled where !snippet.trigger.isEmpty {
            let trigger = Array(snippet.trigger)
            guard buffer.count >= trigger.count,
                  buffer.suffix(trigger.count).elementsEqual(trigger)
            else { continue }
            return SnippetMatch(snippet: snippet, triggerLength: trigger.count)
        }
        return nil
    }
}
