// SPDX-License-Identifier: MIT
// AutoCloseEngine: insert, nesting, tab-out, overtype, pair backspace,
// smart quotes, invalidations, timeout (CA-4.11: 25+ cases).

import XCTest
@testable import ToolboxCore

final class AutoCloseEngineTests: XCTestCase {
    private func makeEngine(
        pairs: [Pair] = Pair.defaults,
        clock: ManualClock? = nil,
        tabOut: Bool = true,
        overtype: Bool = true,
        deletePair: Bool = true,
        smartQuotes: Bool = true
    ) -> (AutoCloseEngine, ManualClock) {
        let clock = clock ?? ManualClock()
        let engine = AutoCloseEngine(
            pairs: pairs,
            tabOut: tabOut,
            overtype: overtype,
            deletePair: deletePair,
            smartQuotes: smartQuotes,
            clock: clock
        )
        return (engine, clock)
    }

    private func type(_ engine: inout AutoCloseEngine, _ chars: String, keyCode: UInt16 = 0, modifiers: KeyModifiers = []) -> AutoCloseAction {
        engine.onKey(keyCode: keyCode, chars: chars, modifiers: modifiers)
    }

    // MARK: - Insert and tab-out (CA-4.1)

    func testOpenParenInsertsPair() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "("), .insertPair(open: "(", close: ")"))
        XCTAssertEqual(engine.depth, 1)
    }

    func testWordThenTabOut() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "("), .insertPair(open: "(", close: ")"))
        for char in "hola" {
            XCTAssertEqual(type(&engine, String(char)), .pass)
        }
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .tabOut)
        XCTAssertEqual(engine.depth, 0)
    }

    func testEmptyPendingTabPasses() {
        // CA-4.7: with an empty stack, Tab behaves normally.
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .pass)
    }

    // MARK: - Nesting (CA-4.3)

    func testNestedPairsUnwindWithTabs() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "("), .insertPair(open: "(", close: ")"))
        XCTAssertEqual(type(&engine, "["), .insertPair(open: "[", close: "]"))
        XCTAssertEqual(engine.depth, 2)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .tabOut)
        XCTAssertEqual(engine.depth, 1)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .tabOut)
        XCTAssertEqual(engine.depth, 0)
    }

    // MARK: - Overtype (CA-4.4)

    func testOvertypeClosingParen() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, ")"), .overtype)
        XCTAssertEqual(engine.depth, 0)
    }

    func testOvertypeDisabledTypesLiterally() {
        var (engine, _) = makeEngine(overtype: false)
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, ")"), .pass)
    }

    func testOvertypeMismatchPasses() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        _ = type(&engine, "[")
        // ")" does not match pending "]": literal, stack kept.
        XCTAssertEqual(type(&engine, ")"), .pass)
        XCTAssertEqual(engine.depth, 2)
    }

    // MARK: - Pair backspace (CA-4.5)

    func testBackspaceDeletesFreshPair() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "\u{7F}", keyCode: SpecialKey.backspace), .deletePair)
        XCTAssertEqual(engine.depth, 0)
    }

    func testBackspaceAfterTypingInsidePasses() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        _ = type(&engine, "x")
        XCTAssertEqual(type(&engine, "\u{7F}", keyCode: SpecialKey.backspace), .pass)
    }

    func testBackspacePairDisabledPasses() {
        var (engine, _) = makeEngine(deletePair: false)
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "\u{7F}", keyCode: SpecialKey.backspace), .pass)
    }

    // MARK: - Smart quotes (CA-4.6)

    func testApostropheAfterLetterPasses() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "n")
        XCTAssertEqual(type(&engine, "'"), .pass, "don't must stay untouched")
    }

    func testQuotePairAndOvertype() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "\""), .insertPair(open: "\"", close: "\""))
        for char in "hola" {
            _ = type(&engine, String(char))
        }
        XCTAssertEqual(type(&engine, "\""), .overtype)
    }

    func testSmartQuotesDisabledPairsAfterLetters() {
        var (engine, _) = makeEngine(smartQuotes: false)
        _ = type(&engine, "n")
        XCTAssertEqual(type(&engine, "'"), .insertPair(open: "'", close: "'"))
    }

    func testDigitBeforeQuotePasses() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "5")
        XCTAssertEqual(type(&engine, "'"), .pass)
    }

    // MARK: - Spanish pairs (CA-4.2)

    func testInvertedMarksPair() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "¿"), .insertPair(open: "¿", close: "?"))
        XCTAssertEqual(type(&engine, "¡"), .insertPair(open: "¡", close: "!"))
    }

    func testDisabledPairPasses() {
        var (engine, _) = makeEngine()
        // "<" ships disabled.
        XCTAssertEqual(type(&engine, "<"), .pass)
    }

    func testGuillemetsAndEnglishQuotes() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "«"), .insertPair(open: "«", close: "»"))
        XCTAssertEqual(type(&engine, "“"), .insertPair(open: "“", close: "”"))
    }

    // MARK: - Modifiers and navigation invalidate

    func testCommandComboPassesAndInvalidates() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "v", modifiers: .command), .pass)
        XCTAssertEqual(engine.depth, 0)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .pass)
    }

    func testControlComboPassesAndInvalidates() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "d", modifiers: .control), .pass)
        XCTAssertEqual(engine.depth, 0)
    }

    func testOptionComboPairs() {
        // Spanish ISO brackets arrive as Option combos: must still pair.
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "[", modifiers: .alternate), .insertPair(open: "[", close: "]"))
        XCTAssertEqual(type(&engine, "{", modifiers: [.alternate, .shift]), .insertPair(open: "{", close: "}"))
    }

    func testArrowsInvalidate() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        for key in [SpecialKey.leftArrow, SpecialKey.rightArrow, SpecialKey.upArrow, SpecialKey.downArrow] {
            _ = type(&engine, "(")
            XCTAssertEqual(type(&engine, "", keyCode: key), .pass)
            XCTAssertEqual(engine.depth, 0, "key \(key)")
        }
    }

    func testEscapeReturnInvalidate() {
        var (engine, _) = makeEngine()
        for key in [SpecialKey.escape, SpecialKey.return, SpecialKey.enter, SpecialKey.home, SpecialKey.end, SpecialKey.pageUp, SpecialKey.pageDown] {
            _ = type(&engine, "(")
            XCTAssertEqual(type(&engine, "", keyCode: key), .pass)
            XCTAssertEqual(engine.depth, 0, "key \(key)")
        }
    }

    func testShiftTabInvalidates() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab, modifiers: .shift), .pass)
        XCTAssertEqual(engine.depth, 0)
    }

    func testExplicitInvalidate() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        engine.invalidate()
        XCTAssertEqual(engine.depth, 0)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .pass)
    }

    // MARK: - Dead keys, IME, timeout

    func testDeadKeyPasses() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, ""), .pass)
    }

    func testMultiCharPasses() {
        var (engine, _) = makeEngine()
        XCTAssertEqual(type(&engine, "ab"), .pass)
    }

    func testTimeoutInvalidates() {
        let clock = ManualClock()
        var (engine, _) = makeEngine(clock: clock)
        _ = type(&engine, "(")
        clock.advance(by: 31)
        _ = type(&engine, "x")
        XCTAssertEqual(engine.depth, 0)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .pass)
    }

    func testActivityKeepsStateAlive() {
        let clock = ManualClock()
        var (engine, _) = makeEngine(clock: clock)
        _ = type(&engine, "(")
        clock.advance(by: 20)
        _ = type(&engine, "x")
        clock.advance(by: 20)
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .tabOut)
    }

    // MARK: - Tab-out gating

    func testTabOutDisabledPasses() {
        var (engine, _) = makeEngine(tabOut: false)
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .pass)
        XCTAssertEqual(engine.depth, 0)
    }

    func testTabOutImmediatelyAfterInsert() {
        var (engine, _) = makeEngine()
        _ = type(&engine, "(")
        XCTAssertEqual(type(&engine, "\t", keyCode: SpecialKey.tab), .tabOut)
    }
}
