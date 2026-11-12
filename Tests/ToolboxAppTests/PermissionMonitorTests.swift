// SPDX-License-Identifier: MIT
// PermissionMonitor: no relaunch needed when Accessibility is granted.

import XCTest
@testable import Toolbox

final class PermissionMonitorTests: XCTestCase {
    func testDoesNotFireWhileUntrusted() {
        var trusted = false
        var fired = 0
        let monitor = PermissionMonitor(
            interval: 3600,
            isTrusted: { trusted },
            onGranted: { fired += 1 }
        )
        monitor.start()
        XCTAssertTrue(monitor.isWatching)
        monitor.check()
        XCTAssertEqual(fired, 0)
        monitor.stop()
    }

    func testFiresOnceWhenTrusted() {
        var trusted = false
        var fired = 0
        let monitor = PermissionMonitor(
            interval: 3600,
            isTrusted: { trusted },
            onGranted: { fired += 1 }
        )
        monitor.start()
        trusted = true
        monitor.check()
        XCTAssertEqual(fired, 1)
        XCTAssertFalse(monitor.isWatching)
        monitor.check()
        XCTAssertEqual(fired, 1)
    }

    func testStartWhenAlreadyTrustedFiresImmediately() {
        var fired = 0
        let monitor = PermissionMonitor(
            interval: 3600,
            isTrusted: { true },
            onGranted: { fired += 1 }
        )
        monitor.start()
        XCTAssertEqual(fired, 1)
        XCTAssertFalse(monitor.isWatching)
    }

    func testStartIsIdempotent() {
        var trusted = false
        var fired = 0
        let monitor = PermissionMonitor(
            interval: 3600,
            isTrusted: { trusted },
            onGranted: { fired += 1 }
        )
        monitor.start()
        monitor.start()
        trusted = true
        monitor.check()
        XCTAssertEqual(fired, 1)
    }

    func testStopPreventsPolling() {
        var fired = 0
        let monitor = PermissionMonitor(
            interval: 3600,
            isTrusted: { true },
            onGranted: { fired += 1 }
        )
        monitor.stop()
        XCTAssertFalse(monitor.isWatching)
        XCTAssertEqual(fired, 0)
    }
}
