// SPDX-License-Identifier: MIT
// Snippet body template: {clipboard}, {date}, {time}, {cursor}, {{ escape.

import Foundation

/// Renders a snippet body into insertable text plus cursor placement.
public struct SnippetTemplate {
    public var dateFormat: String
    public var timeFormat: String

    public init(dateFormat: String = "yyyy-MM-dd", timeFormat: String = "HH:mm") {
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
    }

    /// Rendered text (cursor marker removed) and how many characters from the
    /// end the cursor belongs (Left presses after insertion).
    public struct Expansion: Equatable {
        public var text: String
        public var cursorOffsetFromEnd: Int
    }

    public func expand(body: String, clipboard: String, now: Date = Date()) -> Expansion {
        var text = ""
        text.reserveCapacity(body.count)
        var cursorIndex: Int?
        var index = body.startIndex
        while index < body.endIndex {
            if body[index] == "{", let token = readToken(body, from: index) {
                switch token.name {
                case "":
                    // "{{" escape → literal "{".
                    text.append("{")
                case "clipboard":
                    text.append(clipboard)
                case "date":
                    text.append(format(date: now, format: dateFormat))
                case "time":
                    text.append(format(date: now, format: timeFormat))
                case "cursor":
                    // Last marker wins; offset measured at the end.
                    cursorIndex = text.count
                default:
                    // Unknown variables stay literal.
                    text.append("{")
                    text.append(contentsOf: token.name)
                    text.append("}")
                }
                index = token.end
                continue
            }
            text.append(body[index])
            index = body.index(after: index)
        }
        let offset = cursorIndex.map { text.count - $0 } ?? 0
        return Expansion(text: text, cursorOffsetFromEnd: offset)
    }

    private struct Token {
        /// "" for the "{{" escape, otherwise the variable name.
        var name: String
        var end: String.Index
    }

    /// Reads "{name}" (or "{{") starting at an opener. Nil if unterminated.
    private func readToken(_ body: String, from index: String.Index) -> Token? {
        var next = body.index(after: index)
        if next < body.endIndex, body[next] == "{" {
            return Token(name: "", end: body.index(after: next))
        }
        var name = ""
        while next < body.endIndex, body[next] != "}" {
            if body[next] == "{" { return nil }
            name.append(body[next])
            next = body.index(after: next)
        }
        guard next < body.endIndex else { return nil }
        return Token(name: name, end: body.index(after: next))
    }

    private func format(date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
