// SPDX-License-Identifier: MIT
// Snippets: trigger expansion in any app plus a searchable insert panel.
// Priority 10: evaluated before Auto-close and Vim Scroll.

import AppKit
import CoreGraphics
import SwiftUI
import ToolboxCore

/// Expands short triggers into full text. Trigger text is erased with
/// backspaces; bodies over 200 UTF-16 units paste via the clipboard.
final class SnippetsFeature: NSObject, TapConsumer, StatefulFeature {
    static let descriptor = FeatureDescriptor(
        id: .snippets,
        titleKey: "Snippets",
        kind: .toggle,
        requiredPermissions: [.accessibility],
        menuOrder: 4
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    var onChange: (() -> Void)?
    let tapPriority = 10
    private(set) var isRunning = false

    /// Bodies longer than this paste instead of typing.
    static let pasteThreshold = 200

    private let store: SettingsStore
    private let snippetStore: SnippetStore
    private let tapManager: EventTapManager
    private let frontmostBundleID: () -> String?
    private let focusSnapshot: () -> FocusSnapshot
    private var engine = SnippetEngine()
    private var lastBundleID: String?
    private var previousApp: NSRunningApplication?
    private var pickerPanel: NSPanel?

    /// Paste path seam (tests capture instead of touching the clipboard).
    var pasteText: (String) -> Void = TextInserter.paste

    init(
        store: SettingsStore,
        snippetStore: SnippetStore? = nil,
        tapManager: EventTapManager,
        frontmostBundleID: @escaping () -> String?,
        focusSnapshot: @escaping () -> FocusSnapshot
    ) {
        self.store = store
        self.snippetStore = snippetStore ?? SnippetStore()
        self.tapManager = tapManager
        self.frontmostBundleID = frontmostBundleID
        self.focusSnapshot = focusSnapshot
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
        guard store.settings.snippets.filter.allows(bundleID) else {
            engine.invalidate()
            return .pass
        }
        let flags = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            engine.invalidate()
            return .pass
        }
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        switch keyCode {
        case SpecialKey.leftArrow, SpecialKey.rightArrow, SpecialKey.upArrow, SpecialKey.downArrow,
             SpecialKey.escape, SpecialKey.home, SpecialKey.end, SpecialKey.pageUp, SpecialKey.pageDown:
            engine.invalidate()
            return .pass
        default:
            break
        }
        refreshEngine()
        let chars = AutoCloseFeature.unicodeString(for: event)
        guard chars.count == 1, let char = chars.first else { return .pass }
        guard let match = engine.input(char) else { return .pass }
        // In immediate mode the triggering char belongs to the trigger itself.
        if store.settings.snippets.expandImmediately {
            return expand(match: match, delimiter: .none)
        }
        let delimiter: Delimiter
        if keyCode == SpecialKey.tab {
            delimiter = .tab
        } else if keyCode == SpecialKey.return {
            delimiter = .return
        } else {
            delimiter = .text(char)
        }
        return expand(match: match, delimiter: delimiter)
    }

    private enum Delimiter {
        /// Immediate mode: no delimiter typed.
        case none
        /// A text delimiter (space, punctuation) re-typed after insertion.
        case text(Character)
        case tab
        case `return`
    }

    private func expand(match: SnippetMatch, delimiter: Delimiter) -> TapResult {
        let settings = store.settings.snippets
        let template = SnippetTemplate(dateFormat: settings.dateFormat, timeFormat: settings.timeFormat)
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let expansion = template.expand(body: match.snippet.body, clipboard: clipboard)
        var events: [CGEvent] = []
        for _ in 0 ..< match.triggerLength {
            events.append(contentsOf: KeyPoster.press(keyCode: KeyCode.backspace))
        }
        if expansion.text.utf16.count > Self.pasteThreshold {
            // Long body: erase now, paste + cursor asynchronously.
            pasteText(expansion.text)
            if expansion.cursorOffsetFromEnd > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [offset = expansion.cursorOffsetFromEnd] in
                    for _ in 0 ..< offset {
                        for event in KeyPoster.press(keyCode: KeyCode.leftArrow) {
                            event.post(tap: .cghidEventTap)
                        }
                    }
                }
            }
        } else {
            events.append(contentsOf: TextInserter.typeEvents(for: expansion.text))
            for _ in 0 ..< expansion.cursorOffsetFromEnd {
                events.append(contentsOf: KeyPoster.press(keyCode: KeyCode.leftArrow))
            }
            switch delimiter {
            case .none:
                break
            case .text(let char):
                events.append(contentsOf: TextInserter.typeEvents(for: String(char)))
            case .tab:
                reemit(keyCode: SpecialKey.tab)
            case .return:
                reemit(keyCode: SpecialKey.return)
            }
        }
        return .replace(events)
    }

    /// Re-posts Tab/Return unmarked so focus-move/send still happen.
    private func reemit(keyCode: CGKeyCode) {
        DispatchQueue.main.async {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
            else { return }
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private func refreshEngine() {
        engine.snippets = snippetStore.snippets
        engine.expandOnDelimiter = store.settings.snippets.expandOnDelimiter
        engine.expandImmediately = store.settings.snippets.expandImmediately
    }

    // MARK: - Submenu and picker

    func makeSubmenu() -> NSMenu? {
        let menu = NSMenu()
        let item = NSMenuItem(
            title: NSLocalizedString("Insert Snippet…", comment: ""),
            action: #selector(openPicker(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
        return menu
    }

    @objc private func openPicker(_: NSMenuItem) {
        previousApp = NSWorkspace.shared.frontmostApplication
        if pickerPanel == nil {
            let view = SnippetPickerView(
                snippets: snippetStore.snippets,
                onPick: { [weak self] snippet in self?.insertFromPicker(snippet) }
            )
            let hosting = NSHostingController(rootView: view)
            let panel = NSPanel(contentViewController: hosting)
            panel.title = NSLocalizedString("Insert Snippet", comment: "")
            panel.styleMask = [.titled, .closable, .resizable]
            panel.center()
            pickerPanel = panel
        } else if let view = (pickerPanel?.contentViewController as? NSHostingController<SnippetPickerView>)?.rootView {
            // Refresh the list each time it opens.
            _ = view
        }
        pickerPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Pastes into the app that was focused before the picker opened.
    func insertFromPicker(_ snippet: Snippet) {
        pickerPanel?.orderOut(nil)
        let settings = store.settings.snippets
        let template = SnippetTemplate(dateFormat: settings.dateFormat, timeFormat: settings.timeFormat)
        let clipboard = NSPasteboard.general.string(forType: .string) ?? ""
        let expansion = template.expand(body: snippet.body, clipboard: clipboard)
        guard PermissionsService.isAccessibilityTrusted() else {
            // No AX: copy and let the user paste (CA-6.4).
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(expansion.text, forType: .string)
            let toast = NSLocalizedString("Copied — paste it yourself", comment: "")
            HudToast.show(text: toast)
            return
        }
        if let previousApp {
            previousApp.activate(options: [.activateIgnoringOtherApps])
        }
        let text = expansion.text
        let offset = expansion.cursorOffsetFromEnd
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            TextInserter.paste(text: text)
            if offset > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    for _ in 0 ..< offset {
                        for event in KeyPoster.press(keyCode: KeyCode.leftArrow) {
                            event.post(tap: .cghidEventTap)
                        }
                    }
                }
            }
        }
    }
}
