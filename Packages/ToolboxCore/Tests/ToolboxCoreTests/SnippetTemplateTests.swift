// SPDX-License-Identifier: MIT
// SnippetTemplate: variables, cursor placement, escapes.

import XCTest
@testable import ToolboxCore

final class SnippetTemplateTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13:20 UTC

    func testPlainText() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "hello", clipboard: "X", now: fixedDate)
        XCTAssertEqual(expansion, SnippetTemplate.Expansion(text: "hello", cursorOffsetFromEnd: 0))
    }

    func testClipboard() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "copy: {clipboard}!", clipboard: "PASTE", now: fixedDate)
        XCTAssertEqual(expansion.text, "copy: PASTE!")
        XCTAssertEqual(expansion.cursorOffsetFromEnd, 0)
    }

    func testDateAndTime() {
        // Expectations derived with an independent formatter (system zone).
        let expected = Self.formatted(date: fixedDate)
        let template = SnippetTemplate(dateFormat: "yyyy-MM-dd", timeFormat: "HH:mm")
        XCTAssertEqual(template.expand(body: "{date}", clipboard: "", now: fixedDate).text, expected.date)
        XCTAssertEqual(template.expand(body: "{time}", clipboard: "", now: fixedDate).text, expected.time)
    }

    private static func formatted(date: Date) -> (date: String, time: String) {
        let locale = Locale(identifier: "en_US_POSIX")
        let day = DateFormatter()
        day.locale = locale
        day.dateFormat = "yyyy-MM-dd"
        let clock = DateFormatter()
        clock.locale = locale
        clock.dateFormat = "HH:mm"
        return (day.string(from: date), clock.string(from: date))
    }

    func testCursorAtEnd() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "ab{cursor}", clipboard: "", now: fixedDate)
        XCTAssertEqual(expansion.text, "ab")
        XCTAssertEqual(expansion.cursorOffsetFromEnd, 0)
    }

    func testCursorInMiddle() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "say {cursor} now", clipboard: "", now: fixedDate)
        XCTAssertEqual(expansion.text, "say  now")
        XCTAssertEqual(expansion.cursorOffsetFromEnd, 4)
    }

    func testCursorWithVariableAfter() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "{cursor}{date}", clipboard: "", now: fixedDate)
        XCTAssertEqual(expansion.text, Self.formatted(date: fixedDate).date)
        XCTAssertEqual(expansion.cursorOffsetFromEnd, expansion.text.count)
    }

    func testEscape() {
        let template = SnippetTemplate()
        XCTAssertEqual(template.expand(body: "{{date}}", clipboard: "", now: fixedDate).text, "{date}}")
    }

    func testUnknownVariableLiteral() {
        let template = SnippetTemplate()
        XCTAssertEqual(template.expand(body: "{foo}", clipboard: "", now: fixedDate).text, "{foo}")
    }

    func testUnterminatedBraceLiteral() {
        let template = SnippetTemplate()
        XCTAssertEqual(template.expand(body: "a{date", clipboard: "", now: fixedDate).text, "a{date")
    }

    func testMultipleVariables() {
        let template = SnippetTemplate()
        let expansion = template.expand(body: "{clipboard} on {date}", clipboard: "C", now: fixedDate)
        XCTAssertEqual(expansion.text, "C on " + Self.formatted(date: fixedDate).date)
    }
}
