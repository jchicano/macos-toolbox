// SPDX-License-Identifier: MIT
// SnippetsFeature handle(): expansion, cursor, gates, picker filter.

import CoreGraphics
import XCTest
import ToolboxCore
@testable import Toolbox

final class SnippetsFeatureTests: XCTestCase {
    private var bundleID: String?
    private var pasted: [String] = []

    private func makeFeature(
        snippets: [Snippet]? = nil,
        expandImmediately: Bool = false
    ) -> (SnippetsFeature, SettingsStore, EventTapManager) {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        store.update {
            $0.snippets.expandOnDelimiter = true
            $0.snippets.expandImmediately = expandImmediately
        }
        let tracker = FrontmostAppTracker()
        let cache = FocusedElementCache(tracker: tracker)
        let tapManager = EventTapManager(tracker: tracker, focusCache: cache)
        let snippetStore = SnippetStore(snippets: snippets ?? [Snippet(trigger: ";sig", title: "Signature", body: "Best")])
        let feature = SnippetsFeature(
            store: store,
            snippetStore: snippetStore,
            tapManager: tapManager,
            frontmostBundleID: { [weak self] in self?.bundleID },
            focusSnapshot: { FocusSnapshot(role: .other, windowSize: nil, windowOrigin: nil) }
        )
        feature.pasteText = { [weak self] text in self?.pasted.append(text) }
        return (feature, store, tapManager)
    }

    private func keyDown(chars: String, keyCode: UInt16 = 0, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        event.flags = flags
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
        let units = Array(chars.utf16)
        if !units.isEmpty {
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        }
        return event
    }

    func testTriggerPlusSpaceReplaces() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        for char in ";sig" {
            XCTAssertEqual(feature.handle(event: keyDown(chars: String(char)), type: .keyDown), .pass)
        }
        let result = feature.handle(event: keyDown(chars: " "), type: .keyDown)
        guard case .replace(let events) = result else {
            return XCTFail("expected replace, got \(result)")
        }
        // 4 backspaces (8 events) + "Best" (2) + " " delimiter (2).
        XCTAssertEqual(events.count, 12)
        XCTAssertTrue(pasted.isEmpty)
    }

    func testCursorPlacementAppendsLeftArrows() {
        bundleID = "com.apple.TextEdit"
        let body = Snippet(trigger: ";sig", title: "S", body: "a{cursor}b")
        let (feature, _, _) = makeFeature(snippets: [body])
        for char in ";sig" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        guard case .replace(let events) = feature.handle(event: keyDown(chars: " "), type: .keyDown) else {
            return XCTFail("expected replace")
        }
        // 8 backspace + 2 type + 2 left + 2 delimiter-space.
        XCTAssertEqual(events.count, 14)
    }

    func testNoMatchPasses() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        for char in ";no" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        XCTAssertEqual(feature.handle(event: keyDown(chars: " "), type: .keyDown), .pass)
    }

    func testDisabledSnippetPasses() {
        bundleID = "com.apple.TextEdit"
        var snippet = Snippet(trigger: ";sig", title: "S", body: "Best")
        snippet.enabled = false
        let (feature, _, _) = makeFeature(snippets: [snippet])
        for char in ";sig" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        XCTAssertEqual(feature.handle(event: keyDown(chars: " "), type: .keyDown), .pass)
    }

    func testBlockedAppPasses() {
        bundleID = "com.apple.Terminal"
        let (feature, store, _) = makeFeature()
        store.update { $0.snippets.filter = AppFilter(mode: .denylist, bundleIDs: ["com.apple.Terminal"]) }
        for char in ";sig" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        XCTAssertEqual(feature.handle(event: keyDown(chars: " "), type: .keyDown), .pass)
    }

    func testCommandInvalidates() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        for char in ";si" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        XCTAssertEqual(feature.handle(event: keyDown(chars: "v", keyCode: 9, flags: .maskCommand), type: .keyDown), .pass)
        // Buffer was cleared: completing the trigger no longer matches.
        XCTAssertEqual(feature.handle(event: keyDown(chars: "g"), type: .keyDown), .pass)
        XCTAssertEqual(feature.handle(event: keyDown(chars: " "), type: .keyDown), .pass)
    }

    func testImmediateMode() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature(expandImmediately: true)
        var result: TapResult = .pass
        for char in ";sig" {
            result = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        guard case .replace(let events) = result else {
            return XCTFail("expected replace, got \(result)")
        }
        // 8 backspace + 2 type, no delimiter.
        XCTAssertEqual(events.count, 10)
    }

    func testLongBodyUsesPaste() {
        bundleID = "com.apple.TextEdit"
        let long = Snippet(trigger: ";sig", title: "S", body: String(repeating: "x", count: 250))
        let (feature, _, _) = makeFeature(snippets: [long])
        for char in ";sig" {
            _ = feature.handle(event: keyDown(chars: String(char)), type: .keyDown)
        }
        guard case .replace(let events) = feature.handle(event: keyDown(chars: " "), type: .keyDown) else {
            return XCTFail("expected replace")
        }
        // Only backspaces inline; the body goes through the paste seam.
        XCTAssertEqual(events.count, 8)
        XCTAssertEqual(pasted, [String(repeating: "x", count: 250)])
    }

    func testDeadKeyPasses() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        XCTAssertEqual(feature.handle(event: keyDown(chars: ""), type: .keyDown), .pass)
    }

    func testPriorityBelowAutoClose() {
        // Order is Snippets(10) → AutoClose(20) → ScrollVim(30).
        let (feature, _, _) = makeFeature()
        XCTAssertEqual(feature.tapPriority, 10)
        XCTAssertLessThan(feature.tapPriority, AutoCloseFeature.descriptor.menuOrder * 10)
    }

    func testStartThrowsWithoutPermission() {
        let (feature, _, _) = makeFeature()
        XCTAssertThrowsError(try feature.start()) { error in
            XCTAssertEqual(error as? FeatureError, .permissionMissing(.accessibility))
        }
        XCTAssertFalse(feature.isRunning)
    }

    func testStopIsSafeWhenNeverStarted() {
        let (feature, _, tapManager) = makeFeature()
        feature.stop()
        XCTAssertFalse(feature.isRunning)
        XCTAssertEqual(tapManager.consumerCount, 0)
    }

    // MARK: - Picker filter

    func testFilterEmptyQueryReturnsEnabled() {
        let snippets = [
            Snippet(trigger: ";b", title: "B", body: "b"),
            Snippet(trigger: ";a", title: "A", body: "a", enabled: false),
        ]
        XCTAssertEqual(filterSnippets(snippets, query: "").map(\.trigger), [";b"])
    }

    func testFilterPrefixFirst() {
        let snippets = [
            Snippet(trigger: ";signature", title: "Signature", body: "s"),
            Snippet(trigger: ";sig", title: "Short", body: "s"),
        ]
        XCTAssertEqual(filterSnippets(snippets, query: "sig").map(\.trigger), [";sig", ";signature"])
    }

    func testFilterMatchesTitle() {
        let snippets = [Snippet(trigger: ";addr", title: "Address", body: "a")]
        XCTAssertEqual(filterSnippets(snippets, query: "ADDRESS").map(\.trigger), [";addr"])
        XCTAssertTrue(filterSnippets(snippets, query: "zzz").isEmpty)
    }
}
