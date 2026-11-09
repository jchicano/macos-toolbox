// SPDX-License-Identifier: MIT
// AutoCloseFeature handle(): pair insertion, tab-out, gates, title.

import CoreGraphics
import XCTest
import ToolboxCore
@testable import Toolbox

final class AutoCloseFeatureTests: XCTestCase {
    private var bundleID: String?
    private var role = FocusRole.other

    private func makeFeature() -> (AutoCloseFeature, SettingsStore, EventTapManager) {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        let tracker = FrontmostAppTracker()
        let cache = FocusedElementCache(tracker: tracker)
        let tapManager = EventTapManager(tracker: tracker, focusCache: cache)
        let feature = AutoCloseFeature(
            store: store,
            tapManager: tapManager,
            frontmostBundleID: { [weak self] in self?.bundleID },
            focusSnapshot: { [weak self] in FocusSnapshot(role: self?.role ?? .other, windowSize: nil, windowOrigin: nil) }
        )
        return (feature, store, tapManager)
    }

    /// keyDown with resolved Unicode text (as the layout would produce).
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

    func testOpenParenReplaces() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        let result = feature.handle(event: keyDown(chars: "("), type: .keyDown)
        guard case .replace(let events) = result else {
            return XCTFail("expected replace, got \(result)")
        }
        // "(+)" typing (2 events) + Left (2 events).
        XCTAssertEqual(events.count, 4)
    }

    func testTabOutAfterPair() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        _ = feature.handle(event: keyDown(chars: "("), type: .keyDown)
        let result = feature.handle(event: keyDown(chars: "\t", keyCode: 48), type: .keyDown)
        guard case .replace(let events) = result else {
            return XCTFail("expected replace, got \(result)")
        }
        XCTAssertEqual(events.count, 2)
    }

    func testPlainTabPassesWhenEmpty() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        XCTAssertEqual(feature.handle(event: keyDown(chars: "\t", keyCode: 48), type: .keyDown), .pass)
    }

    func testOvertype() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        _ = feature.handle(event: keyDown(chars: "("), type: .keyDown)
        guard case .replace(let events) = feature.handle(event: keyDown(chars: ")"), type: .keyDown) else {
            return XCTFail("expected overtype replace")
        }
        XCTAssertEqual(events.count, 2)
    }

    func testBlockedAppPassesAndInvalidates() {
        bundleID = "com.microsoft.VSCode"
        let (feature, _, _) = makeFeature()
        XCTAssertEqual(feature.handle(event: keyDown(chars: "("), type: .keyDown), .pass)
    }

    func testAppSwitchInvalidates() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        _ = feature.handle(event: keyDown(chars: "("), type: .keyDown)
        bundleID = "com.apple.Notes"
        // Pending state from TextEdit must not leak into Notes.
        XCTAssertEqual(feature.handle(event: keyDown(chars: "\t", keyCode: 48), type: .keyDown), .pass)
    }

    func testMouseClickInvalidates() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        _ = feature.handle(event: keyDown(chars: "("), type: .keyDown)
        let click = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: .zero, mouseButton: .left)!
        XCTAssertEqual(feature.handle(event: click, type: .leftMouseDown), .pass)
        XCTAssertEqual(feature.handle(event: keyDown(chars: "\t", keyCode: 48), type: .keyDown), .pass)
    }

    func testCommandPasses() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        XCTAssertEqual(
            feature.handle(event: keyDown(chars: "v", keyCode: 9, flags: .maskCommand), type: .keyDown),
            .pass
        )
    }

    func testNonKeyDownPasses() {
        bundleID = "com.apple.TextEdit"
        let (feature, _, _) = makeFeature()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        XCTAssertEqual(feature.handle(event: event, type: .keyUp), .pass)
    }

    func testRequireEditableFocusGate() {
        bundleID = "com.apple.TextEdit"
        role = .unknown
        let (feature, store, _) = makeFeature()
        store.update { $0.autoClose.requireEditableFocus = true }
        XCTAssertEqual(feature.handle(event: keyDown(chars: "("), type: .keyDown), .pass)
        role = .textInput
        if case .replace = feature.handle(event: keyDown(chars: "("), type: .keyDown) {
        } else {
            XCTFail("expected replace in text input")
        }
    }

    func testMenuTitleListsActiveOpeners() {
        let (feature, _, _) = makeFeature()
        let title = feature.menuTitle ?? ""
        XCTAssertTrue(title.hasPrefix("Auto-close "))
        XCTAssertTrue(title.contains("("))
        XCTAssertTrue(title.contains("¿"))
        XCTAssertFalse(title.contains("<"))
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
}
