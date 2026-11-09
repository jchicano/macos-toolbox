// SPDX-License-Identifier: MIT
// Application delegate: builds the controller, restores state, stops on quit.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep a strong reference for the whole process lifetime.
        statusItemController = StatusItemController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusItemController?.shutdown()
        statusItemController = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
