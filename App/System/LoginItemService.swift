// SPDX-License-Identifier: MIT
// Launch at Login. Modern API on macOS 13+, legacy helper on macOS 12.

import Foundation
import ServiceManagement
import ToolboxCore

/// Persists the desired state in Settings and applies it to the system.
/// On macOS 12 the legacy helper (ToolboxLoginItem.app, embedded at
/// Contents/Library/LoginItems) is toggled via SMLoginItemSetEnabled.
final class LoginItemService {
    static let helperBundleID = "com.jchicano.toolbox.loginitem"

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
    }

    var isEnabled: Bool {
        if #available(macOS 13, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return store.settings.launchAtLogin
    }

    func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } else {
            // Deprecated in macOS 13 SDK but required on macOS 12.
            SMLoginItemSetEnabled(Self.helperBundleID as CFString, enabled)
        }
        store.update { $0.launchAtLogin = enabled }
    }

    /// Re-applies the stored preference (call once at launch).
    func applyStored() {
        try? setEnabled(store.settings.launchAtLogin)
    }
}
