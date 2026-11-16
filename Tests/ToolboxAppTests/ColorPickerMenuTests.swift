// SPDX-License-Identifier: MIT
// Color picker menu: the sampler must be reachable even though the item has a
// submenu (AppKit does not send the parent item's action when a submenu exists).

import XCTest
import ToolboxCore
@testable import Toolbox

final class ColorPickerMenuTests: XCTestCase {
    private func makeAction(recents: [String] = []) -> ColorPickerAction {
        let defaults = UserDefaults(suiteName: #function + UUID().uuidString)!
        let store = SettingsStore(defaults: defaults)
        if !recents.isEmpty {
            store.update { $0.colorPicker.recents = recents }
        }
        return ColorPickerAction(store: store)
    }

    func testSubmenuStartsWithPickColorAction() {
        let action = makeAction()
        let first = action.makeSubmenu()?.items.first
        XCTAssertEqual(first?.title, "Pick Color…")
        XCTAssertNotNil(first?.action)
        XCTAssertTrue(first?.target === action)
    }

    func testSubmenuStillExposesFormatAndRecent() {
        let titles = makeAction(recents: ["#FFFFFF"]).makeSubmenu()?.items.map(\.title) ?? []
        XCTAssertTrue(titles.contains("Format"))
        XCTAssertTrue(titles.contains("Recent"))
    }
}
