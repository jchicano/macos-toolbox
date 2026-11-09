// SPDX-License-Identifier: MIT
// Auto-close: pairs the opener, Tab jumps out, overtype and pair backspace.
// Works on characters (layout-independent), not keycodes.

import AppKit
import CoreGraphics
import ToolboxCore

/// Feeds resolved Unicode into AutoCloseEngine and posts the returned action.
/// Priority 20: after Snippets, before ScrollVim.
final class AutoCloseFeature: NSObject, TapConsumer, StatefulFeature {
    static let descriptor = FeatureDescriptor(
        id: .autoClose,
        titleKey: "Auto-close",
        kind: .toggle,
        requiredPermissions: [.accessibility],
        menuOrder: 3
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    var onChange: (() -> Void)?

    /// "Auto-close ( [ { …" from the enabled openers.
    var menuTitle: String? {
        let openers = store.settings.autoClose.pairs
            .filter(\.enabled)
            .map(\.open)
            .joined(separator: " ")
        let base = NSLocalizedString(Self.descriptor.titleKey, comment: "")
        return openers.isEmpty ? base : "\(base) \(openers)"
    }

    let tapPriority = 20
    private(set) var isRunning = false

    private let store: SettingsStore
    private let tapManager: EventTapManager
    private let frontmostBundleID: () -> String?
    private let focusSnapshot: () -> FocusSnapshot
    private var engine: AutoCloseEngine
    private var lastBundleID: String?

    init(
        store: SettingsStore,
        tapManager: EventTapManager,
        frontmostBundleID: @escaping () -> String?,
        focusSnapshot: @escaping () -> FocusSnapshot
    ) {
        self.store = store
        self.tapManager = tapManager
        self.frontmostBundleID = frontmostBundleID
        self.focusSnapshot = focusSnapshot
        engine = AutoCloseEngine(pairs: store.settings.autoClose.pairs)
        super.init()
    }

    /// Convenience wiring for production (tracker + cache).
    convenience init(store: SettingsStore, tapManager: EventTapManager, tracker: FrontmostAppTracker, focusCache: FocusedElementCache) {
        self.init(
            store: store,
            tapManager: tapManager,
            frontmostBundleID: { tracker.frontmostBundleID },
            focusSnapshot: { focusCache.snapshot }
        )
    }

    func start() throws {
        guard PermissionsService.isAccessibilityTrusted() else {
            throw FeatureError.permissionMissing(.accessibility)
        }
        refreshEngine()
        tapManager.addConsumer(self)
        isRunning = true
        onChange?()
    }

    func stop() {
        tapManager.removeConsumer(self)
        isRunning = false
        onChange?()
    }

    func handle(event: CGEvent, type: CGEventType) -> TapResult {
        if type == .leftMouseDown || type == .rightMouseDown {
            engine.invalidate()
            return .pass
        }
        guard type == .keyDown else { return .pass }
        let bundleID = frontmostBundleID()
        if bundleID != lastBundleID {
            lastBundleID = bundleID
            engine.invalidate()
        }
        guard store.settings.autoClose.filter.allows(bundleID) else {
            engine.invalidate()
            return .pass
        }
        if store.settings.autoClose.requireEditableFocus,
           focusSnapshot().role != .textInput
        {
            engine.invalidate()
            return .pass
        }
        refreshEngine()
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifiers = Self.modifiers(for: event.flags)
        let chars = Self.unicodeString(for: event)
        switch engine.onKey(keyCode: keyCode, chars: chars, modifiers: modifiers) {
        case .pass:
            return .pass
        case .insertPair(let open, let close):
            return .replace(TextInserter.typeEvents(for: open + close) + KeyPoster.press(keyCode: KeyCode.leftArrow))
        case .tabOut, .overtype:
            return .replace(KeyPoster.press(keyCode: KeyCode.rightArrow))
        case .deletePair:
            return .replace(KeyPoster.press(keyCode: KeyCode.backspace) + KeyPoster.press(keyCode: KeyCode.forwardDelete))
        }
    }

    private func refreshEngine() {
        let settings = store.settings.autoClose
        var table: [Character: Character] = [:]
        for pair in settings.pairs where pair.enabled {
            if let open = pair.open.first, let close = pair.close.first {
                table[open] = close
            }
        }
        engine.pairs = table
        engine.tabOutEnabled = settings.tabOut
        engine.overtypeEnabled = settings.overtype
        engine.deletePairEnabled = settings.deletePair
        engine.smartQuotesEnabled = settings.smartQuotes
    }

    private static func modifiers(for flags: CGEventFlags) -> KeyModifiers {
        var result: KeyModifiers = []
        if flags.contains(.maskCommand) { result.insert(.command) }
        if flags.contains(.maskControl) { result.insert(.control) }
        if flags.contains(.maskAlternate) { result.insert(.alternate) }
        if flags.contains(.maskShift) { result.insert(.shift) }
        return result
    }

    /// Resolved Unicode for the keyDown ("" for dead keys).
    static func unicodeString(for event: CGEvent) -> String {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 8)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else { return "" }
        return String(utf16CodeUnits: buffer, count: min(length, buffer.count))
    }
}
