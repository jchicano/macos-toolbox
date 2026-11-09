// SPDX-License-Identifier: MIT
// Minimal permission check for F1 gating. Full PermissionsService lands in F3.

import ApplicationServices
import Foundation

/// Reads the Accessibility trust state without prompting.
enum PermissionCheck {
    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }
}
