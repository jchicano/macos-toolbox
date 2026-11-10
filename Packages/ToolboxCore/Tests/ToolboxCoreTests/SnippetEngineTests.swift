// SPDX-License-Identifier: MIT
// SnippetEngine: triggers, delimiters, prefixes, invalidation, Unicode (CA-6.5).

import XCTest
@testable import ToolboxCore

final class SnippetEngineTests: XCTestCase {
    private func sig(body: String = "Best") -> Snippet {
        Snippet(trigger: ";sig", title: "Signature", body: body)
    }

    private func feed(_ engine: inout SnippetEngine, _ text: String) -> SnippetMatch? {
        var match: SnippetMatch?
        for char in text {
            match = engine.input(char)
        }
        return match
    }

    // MARK: - Delimiter mode (default)

    func testTriggerPlusSpaceExpands() {
        var engine = SnippetEngine(snippets: [sig()])
        let match = feed(&engine, ";sig ")
        XCTAssertEqual(match?.snippet.trigger, ";sig")
        XCTAssertEqual(match?.triggerLength, 4)
    }

    func testNoDelimiterNoExpansion() {
        var engine = SnippetEngine(snippets: [sig()])
        XCTAssertNil(feed(&engine, ";sig"))
    }

    func testPunctuationDelimiters() {
        for delimiter in [".", ",", "!", "?", ":", "\n", "\t"] {
            var engine = SnippetEngine(snippets: [sig()])
            XCTAssertNotNil(feed(&engine, ";sig" + delimiter), "delimiter \(delimiter)")
        }
    }

    func testSemicolonIsNotDelimiter() {
        // Triggers start with ";" — typing it must not complete anything.
        var engine = SnippetEngine(snippets: [sig()])
        XCTAssertNil(feed(&engine, ";"))
    }

    func testUnknownTriggerPasses() {
        var engine = SnippetEngine(snippets: [sig()])
        XCTAssertNil(feed(&engine, ";nope "))
    }

    func testDisabledSnippetIgnored() {
        var disabled = sig()
        disabled.enabled = false
        var engine = SnippetEngine(snippets: [disabled])
        XCTAssertNil(feed(&engine, ";sig "))
    }

    func testOverlappingPrefixesLongestWins() {
        let short = Snippet(trigger: ";s", title: "S", body: "short")
        var engine = SnippetEngine(snippets: [short, sig()])
        // ";s " alone matches the short trigger...
        XCTAssertEqual(feed(&engine, ";s ")?.snippet.trigger, ";s")
        // ...but ";sig " prefers the longer one.
        var engine2 = SnippetEngine(snippets: [short, sig()])
        XCTAssertEqual(feed(&engine2, ";sig ")?.snippet.trigger, ";sig")
    }

    func testBufferInvalidation() {
        var engine = SnippetEngine(snippets: [sig()])
        _ = feed(&engine, ";si")
        engine.invalidate()
        XCTAssertNil(feed(&engine, "g "))
    }

    func testUnicodeTriggerAndBody() {
        let snippet = Snippet(trigger: ";dirección", title: "Addr", body: "Calle áéí")
        var engine = SnippetEngine(snippets: [snippet])
        let match = feed(&engine, ";dirección ")
        XCTAssertEqual(match?.snippet.trigger, ";dirección")
        XCTAssertEqual(match?.triggerLength, 10)
    }

    func testAccentedCharsBufferNormally() {
        var engine = SnippetEngine(snippets: [sig()])
        XCTAssertNil(feed(&engine, "¿qué tal? "))
    }

    func testLongInputKeepsTail() {
        // Buffer caps at 32; an old trigger prefix scrolls out.
        var engine = SnippetEngine(snippets: [sig()])
        _ = feed(&engine, String(repeating: "x", count: 40))
        XCTAssertNotNil(feed(&engine, ";sig "))
    }

    func testEmptyTriggerNeverMatches() {
        var engine = SnippetEngine(snippets: [Snippet(trigger: "", title: "E", body: "b")])
        XCTAssertNil(feed(&engine, "hello "))
    }

    // MARK: - Immediate mode

    func testImmediateModeExpandsWithoutDelimiter() {
        var engine = SnippetEngine(snippets: [sig()], expandOnDelimiter: true, expandImmediately: true)
        let match = feed(&engine, ";sig")
        XCTAssertEqual(match?.snippet.trigger, ";sig")
    }

    func testImmediateModeDisabledSnippet() {
        var disabled = sig()
        disabled.enabled = false
        var engine = SnippetEngine(snippets: [disabled], expandOnDelimiter: true, expandImmediately: true)
        XCTAssertNil(feed(&engine, ";sig"))
    }

    // MARK: - Store seed/files

    func testSeedContainsDateAndSig() {
        let triggers = SnippetStore.seed.map(\.trigger)
        XCTAssertTrue(triggers.contains(";date"))
        XCTAssertTrue(triggers.contains(";sig"))
    }

    func testStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("snippets.json")
        let store = SnippetStore(fileURL: url, snippets: [sig()])
        XCTAssertEqual(store.snippets.map(\.trigger), [";sig"])
        store.save()
        let reloaded = SnippetStore(fileURL: url)
        XCTAssertEqual(reloaded.snippets, store.snippets)
    }

    func testStoreSeedsWhenMissing() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = dir.appendingPathComponent("snippets.json")
        let store = SnippetStore(fileURL: url)
        XCTAssertFalse(store.snippets.isEmpty)
    }
}
