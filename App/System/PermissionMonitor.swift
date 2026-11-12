// SPDX-License-Identifier: MIT
// Watches for Accessibility being granted while the app is already running.

import Foundation

/// Polls the Accessibility trust state so a grant takes effect without a
/// relaunch: macOS applies the permission to the running process, so the tap
/// can be installed as soon as the check turns true.
///
/// Used while persisted features are waiting for the permission (first run,
/// revoked and re-granted, or granted after a rebuild invalidated the grant).
final class PermissionMonitor {
    private let interval: TimeInterval
    private let isTrusted: () -> Bool
    private let onGranted: () -> Void
    private var timer: Timer?

    init(
        interval: TimeInterval = 2.0,
        isTrusted: @escaping () -> Bool,
        onGranted: @escaping () -> Void
    ) {
        self.interval = interval
        self.isTrusted = isTrusted
        self.onGranted = onGranted
    }

    /// True while a timer is polling.
    var isWatching: Bool { timer != nil }

    /// Starts polling. Idempotent, and fires immediately if trust is already
    /// granted.
    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.check()
        }
        timer.tolerance = interval / 4
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// One poll while watching. Called by the timer; exposed for tests.
    func check() {
        guard timer != nil else { return }
        poll()
    }

    private func poll() {
        guard isTrusted() else { return }
        stop()
        onGranted()
    }
}
