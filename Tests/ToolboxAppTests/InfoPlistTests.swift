// SPDX-License-Identifier: MIT
// Info.plist values that the system reads with C string APIs must be strings.

import XCTest
@testable import Toolbox

final class InfoPlistTests: XCTestCase {
    func testBundleVersionIsString() {
        // Metal/OpenCL telemetry passes CFBundleVersion to CFStringGetCString.
        // An NSNumber there throws an uncaught exception and aborts the app
        // while drawing the first themed control (see docs/MANUAL_QA.md).
        XCTAssertTrue(
            Bundle.main.infoDictionary?["CFBundleVersion"] is String,
            "CFBundleVersion must be a string"
        )
    }

    func testBundleShortVersionIsString() {
        XCTAssertTrue(Bundle.main.infoDictionary?["CFBundleShortVersionString"] is String)
    }
}
