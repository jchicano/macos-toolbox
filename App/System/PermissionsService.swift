// SPDX-License-Identifier: MIT
// System permission state: Accessibility, event access, Secure Input.

import ApplicationServices
import AppKit
import Carbon
import CoreGraphics
import Foundation

/// Reads permission states and opens Settings. Never prompts except through
/// AXIsProcessTrustedWithOptions when explicitly asked.
enum PermissionsService {
    /// Non-prompting check used for menu state and gating.
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompting check used right before installing the event tap.
    static func requestAccessibilityTrust() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Whether the process may post synthetic events (consumer of the tap).
    static func canPostEvents() -> Bool {
        CGPreflightPostEventAccess()
    }

    /// Whether the process may listen to events (some macOS versions ask).
    static func canListenEvents() -> Bool {
        CGPreflightListenEventAccess()
    }

    /// While secure input is active (password fields, etc.) key features go silent by design.
    static func isSecureInputEnabled() -> Bool {
        IsSecureEventInputEnabled()
    }

    /// Opens System Settings at Privacy & Security › Accessibility.
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
