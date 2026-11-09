// SPDX-License-Identifier: MIT
// AppFilter: denylist, allowlist, wildcard and unknown-app behavior.

import XCTest
@testable import ToolboxCore

final class AppFilterTests: XCTestCase {
    func testDenylistBlocksListedApps() {
        let filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultScrollDeny)
        XCTAssertFalse(filter.allows("com.apple.Terminal"))
        XCTAssertFalse(filter.allows("com.googlecode.iterm2"))
        XCTAssertTrue(filter.allows("com.apple.Safari"))
    }

    func testDenylistWildcard() {
        let filter = AppFilter(mode: .denylist, bundleIDs: ["com.jetbrains.*"])
        XCTAssertFalse(filter.allows("com.jetbrains.intellij"))
        XCTAssertFalse(filter.allows("com.jetbrains.Xcode"))
        XCTAssertTrue(filter.allows("com.jetbrainsx.fake"))
        XCTAssertTrue(filter.allows("com.apple.Notes"))
    }

    func testAllowlist() {
        let filter = AppFilter(mode: .allowlist, bundleIDs: ["com.apple.Safari"])
        XCTAssertTrue(filter.allows("com.apple.Safari"))
        XCTAssertFalse(filter.allows("com.apple.Notes"))
    }

    func testUnknownAppFailOpenOnDenylist() {
        let filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultScrollDeny)
        XCTAssertTrue(filter.allows(nil))
    }

    func testUnknownAppFailClosedOnAllowlist() {
        let filter = AppFilter(mode: .allowlist, bundleIDs: ["com.apple.Safari"])
        XCTAssertFalse(filter.allows(nil))
    }

    func testAutoCloseDenyIncludesEditors() {
        let filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultAutoCloseDeny)
        XCTAssertFalse(filter.allows("com.microsoft.VSCode"))
        XCTAssertFalse(filter.allows("com.apple.dt.Xcode"))
        XCTAssertFalse(filter.allows("md.obsidian"))
        XCTAssertFalse(filter.allows("com.apple.Terminal"))
        XCTAssertTrue(filter.allows("com.apple.TextEdit"))
    }
}
