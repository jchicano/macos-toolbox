// SPDX-License-Identifier: MIT
// MenuBuilder: order, English titles, checks and static items (§0).

import XCTest
import ToolboxCore
@testable import Toolbox

final class MenuBuilderTests: XCTestCase {
    private func makeMenu(granted: Bool = true) -> (NSMenu, FeatureRegistry) {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        let registry = FeatureRegistry(
            features: StubFeature.makeDefaults(),
            store: store,
            isAccessibilityGranted: { granted }
        )
        let target = MenuTarget()
        let menu = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: false,
            actions: MenuActions(
                onToggle: { _ in .disabled },
                onRunAction: { _ in },
                onHelp: {},
                onPreferences: {},
                onLaunchAtLogin: { false },
                onQuit: {}
            ),
            target: target
        )
        return (menu, registry)
    }

    func testMenuOrderAndEnglishTitles() {
        let (menu, _) = makeMenu()
        // 6 features + separator + Help + Preferences + Launch at Login + separator + Quit.
        XCTAssertEqual(menu.items.count, 12)
        let expected = ["Breaks", "Keep Awake", "Vim Scroll", "Auto-close", "Snippets", "Color Picker"]
        for (index, title) in expected.enumerated() {
            XCTAssertEqual(menu.items[index].title, title, "item \(index)")
        }
        XCTAssertTrue(menu.items[6].isSeparatorItem)
        XCTAssertEqual(menu.items[7].title, "Help")
        XCTAssertEqual(menu.items[8].title, "Preferences…")
        XCTAssertEqual(menu.items[9].title, "Launch at Login")
        XCTAssertTrue(menu.items[10].isSeparatorItem)
        XCTAssertEqual(menu.items[11].title, "Quit Toolbox")
    }

    func testToggleStateFollowsRegistry() {
        let (menuBefore, registry) = makeMenu()
        XCTAssertEqual(menuBefore.items[0].state, .off)
        _ = registry.setEnabled(true, for: .breaks)
        let target = MenuTarget()
        let menuAfter = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: false,
            actions: MenuActions(
                onToggle: { _ in .disabled },
                onRunAction: { _ in },
                onHelp: {},
                onPreferences: {},
                onLaunchAtLogin: { false },
                onQuit: {}
            ),
            target: target
        )
        XCTAssertEqual(menuAfter.items[0].state, .on)
    }
}
