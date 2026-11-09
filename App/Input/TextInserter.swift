// SPDX-License-Identifier: MIT
// Shared keystroke synthesis. Every posted event carries the synthetic mark
// so the tap ignores its own output (no feedback loops).

import AppKit
import CoreGraphics
import Foundation

/// Keycodes used by the input features.
enum KeyCode {
    static let tab: CGKeyCode = 48
    static let backspace: CGKeyCode = 51
    static let escape: CGKeyCode = 53
    static let leftArrow: CGKeyCode = 123
    static let rightArrow: CGKeyCode = 124
    static let forwardDelete: CGKeyCode = 117
}

/// Posts marked synthetic events. Requires the same post access as the tap.
enum KeyPoster {
    /// Tag written to every synthetic event. Must match EventTapManager.syntheticMark.
    static let mark: Int64 = 0x544F4F4C // "TOOL"

    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: mark)
    }

    /// Down+up pair for a virtual key, optionally with flags (e.g. command).
    static func press(keyCode: CGKeyCode, flags: CGEventFlags = []) -> [CGEvent] {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else { return [] }
        down.flags = flags
        up.flags = flags
        mark(down)
        mark(up)
        return [down, up]
    }
}

/// Types literal text through the tap path (Unicode chunks, marked synthetic).
enum TextInserter {
    /// Max UTF-16 units per key event (conservative; IME-safe).
    static let chunkSize = 20

    /// Builds down+up Unicode events for the string, chunked.
    static func typeEvents(for text: String) -> [CGEvent] {
        var events: [CGEvent] = []
        for chunk in text.utf16Chunks(of: chunkSize) {
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
            else { continue }
            let units = Array(chunk)
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            KeyPoster.mark(down)
            KeyPoster.mark(up)
            events.append(contentsOf: [down, up])
        }
        return events
    }

    /// Pastes via the clipboard (for long bodies): swaps the clipboard,
    /// posts Cmd+V, restores the previous content. Requires post access.
    static func paste(text: String) {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)
        let savedTypes = pasteboard.types
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        for event in KeyPoster.press(keyCode: 9, flags: .maskCommand) {
            event.post(tap: .cghidEventTap)
        }
        // The target app reads the clipboard on key processing; restore after.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            if let saved {
                pasteboard.setString(saved, forType: .string)
            } else if let savedTypes {
                _ = savedTypes
            }
        }
    }
}

private extension String {
    /// Splits UTF-16 units into chunks of at most `size`.
    func utf16Chunks(of size: Int) -> [[UInt16]] {
        let units = Array(utf16)
        return stride(from: 0, to: units.count, by: size).map { start in
            Array(units[start ..< min(start + size, units.count)])
        }
    }
}
