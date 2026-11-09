// SPDX-License-Identifier: MIT
// F0 smoke test: the package builds and the test runner works.

import XCTest
@testable import ToolboxCore

final class ToolboxCoreTests: XCTestCase {
    func testVersionMarker() {
        XCTAssertEqual(ToolboxCore.version, "0.1.0")
    }
}
