// SPDX-License-Identifier: MIT
// App entry point. The app is an agent (LSUIElement): menu bar only, no Dock icon.

import AppKit

@main
struct ToolboxApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
