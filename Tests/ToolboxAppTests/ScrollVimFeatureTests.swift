// SPDX-License-Identifier: MIT
// ScrollVim handle() logic: modifiers, keycodes, filter, text fields.

import CoreGraphics
import XCTest
import ToolboxCore
@testable import Toolbox

final class ScrollVimFeatureTests: XCTestCase {
    private var bundleID: String?
    private var snapshot = FocusSnapshot(role: .other, windowSize: CGSize(width: 1000, height: 800), windowOrigin: nil)

    private func makeFeature(
        tracker: FrontmostAppTracker? = nil,
        cache: FocusedElementCache? = nil
    ) -> (ScrollVimFeature, SettingsStore, EventTapManager, CapturedScrolls) {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        let tracker = tracker ?? FrontmostAppTracker()
        let cache = cache ?? FocusedElementCache(tracker: tracker)
        let tapManager = EventTapManager(tracker: tracker, focusCache: cache)
        let captured = CapturedScrolls()
        let feature = ScrollVimFeature(
            store: store,
            tapManager: tapManager,
            frontmostBundleID: { [weak self] in self?.bundleID },
            focusSnapshot: { [weak self] in self?.snapshot ?? FocusSnapshot(role: .unknown, windowSize: nil, windowOrigin: nil) }
        )
        feature.poster = { captured.requests.append($0) }
        return (feature, store, tapManager, captured)
    }

    private final class CapturedScrolls {
        var requests: [ScrollRequest] = []
    }

    /// Ctrl+key keyDown with no other modifiers.
    private func ctrlKeyDown(keyCode: CGKeyCode, flags: CGEventFlags = .maskControl) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
        event.flags = flags
        // keyboardEventSource nil does not fill the keycode field; set it.
        event.setIntegerValueField(.keyboardEventKeycode, value: Int64(keyCode))
        return event
    }

    func testCtrlDConsumes() {
        bundleID = "com.apple.Safari"
        let (feature, _, _, captured) = makeFeature()
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .consume)
        // 800 pt window * 0.5 = 400 px down (negative wheel).
        XCTAssertEqual(captured.requests, [ScrollRequest(pixels: -400, smooth: true, location: nil)])
    }

    func testCtrlUConsumes() {
        bundleID = "com.apple.Safari"
        let (feature, _, _, captured) = makeFeature()
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x20), type: .keyDown), .consume)
        XCTAssertEqual(captured.requests, [ScrollRequest(pixels: 400, smooth: true, location: nil)])
    }

    func testScrollTargetsWindowCenter() {
        bundleID = "com.apple.Safari"
        snapshot = FocusSnapshot(
            role: .other,
            windowSize: CGSize(width: 1000, height: 800),
            windowOrigin: CGPoint(x: 100, y: 200)
        )
        let (feature, _, _, captured) = makeFeature()
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .consume)
        XCTAssertEqual(captured.requests.first?.location, CGPoint(x: 600, y: 600))
    }

    func testOtherKeyPasses() {
        bundleID = "com.apple.Safari"
        let (feature, _, _, _) = makeFeature()
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x00), type: .keyDown), .pass)
    }

    func testExtraModifiersPass() {
        bundleID = "com.apple.Safari"
        let (feature, _, _, _) = makeFeature()
        // Cmd, Alt and Shift variants must not trigger (CA-3.4).
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02, flags: [.maskControl, .maskCommand]), type: .keyDown), .pass)
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02, flags: [.maskControl, .maskAlternate]), type: .keyDown), .pass)
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02, flags: [.maskControl, .maskShift]), type: .keyDown), .pass)
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02, flags: []), type: .keyDown), .pass)
    }

    func testKeyUpPasses() {
        bundleID = "com.apple.Safari"
        let (feature, _, _, _) = makeFeature()
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0x02, keyDown: false)!
        event.flags = .maskControl
        XCTAssertEqual(feature.handle(event: event, type: .keyUp), .pass)
    }

    func testDenylistBlocksTerminals() {
        bundleID = "com.apple.Terminal"
        let (feature, _, _, _) = makeFeature()
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .pass)
    }

    func testAllowlistRestricts() {
        bundleID = "com.apple.Notes"
        let (feature, store, _, _) = makeFeature()
        store.update { $0.scrollVim.filter = AppFilter(mode: .allowlist, bundleIDs: ["com.apple.Safari"]) }
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .pass)
        bundleID = "com.apple.Safari"
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .consume)
    }

    func testTextFieldSkipped() {
        bundleID = "com.apple.Safari"
        snapshot = FocusSnapshot(role: .textInput, windowSize: CGSize(width: 1000, height: 800), windowOrigin: nil)
        let (feature, _, _, _) = makeFeature()
        // Ctrl+D in a text field must forward-delete (CA-3.3).
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .pass)
    }

    func testTextFieldSkipDisabled() {
        bundleID = "com.apple.Safari"
        snapshot = FocusSnapshot(role: .textInput, windowSize: CGSize(width: 1000, height: 800), windowOrigin: nil)
        let (feature, store, _, _) = makeFeature()
        store.update { $0.scrollVim.skipTextFields = false }
        XCTAssertEqual(feature.handle(event: ctrlKeyDown(keyCode: 0x02), type: .keyDown), .consume)
    }

    func testStartThrowsWithoutPermission() {
        // Headless runner has no Accessibility grant: start must refuse.
        let (feature, _, _, _) = makeFeature()
        XCTAssertThrowsError(try feature.start()) { error in
            XCTAssertEqual(error as? FeatureError, .permissionMissing(.accessibility))
        }
        XCTAssertFalse(feature.isRunning)
    }

    func testStopIsSafeWhenNeverStarted() {
        let (feature, _, tapManager, _) = makeFeature()
        feature.stop()
        XCTAssertFalse(feature.isRunning)
        XCTAssertEqual(tapManager.consumerCount, 0)
    }
}
