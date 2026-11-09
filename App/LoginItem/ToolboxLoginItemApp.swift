// SPDX-License-Identifier: MIT
// Legacy login item helper (macOS 12). Launched at login by the system,
// it opens the main app and quits. macOS 13+ uses SMAppService instead.

import AppKit

@main
enum LoginItemMain {
    static func main() {
        let app = NSApplication.shared
        if let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.jchicano.toolbox"
        ) {
            NSWorkspace.shared.open(url)
        }
        app.terminate(nil)
    }
}
