// SPDX-License-Identifier: MIT
// Tracks the frontmost app's bundle id on the main thread; the tap callback
// only reads the cached value (never touches NSWorkspace in the tap).

import AppKit
import Foundation

/// Thread-safe cache of the active application's bundle identifier.
final class FrontmostAppTracker: NSObject {
    private let lock = NSLock()
    private var _bundleID: String?

    /// Last seen bundle id, or nil if unknown. Safe from any thread.
    var frontmostBundleID: String? {
        get { lock.synchronized { _bundleID } }
        set { lock.synchronized { _bundleID = newValue } }
    }

    override init() {
        super.init()
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        // Invalidate input state on app switch (consumers observe via tracker or tap events).
        frontmostBundleID = app?.bundleIdentifier
            ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}

private extension NSLock {
    func synchronized<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
