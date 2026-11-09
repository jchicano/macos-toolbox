// SPDX-License-Identifier: MIT
// Application delegate: owns the status item controller for the app lifetime.

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep a strong reference for the whole process lifetime.
        statusItemController = StatusItemController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // F1+: stop every running feature here (energy assertions, event taps).
        statusItemController = nil
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
