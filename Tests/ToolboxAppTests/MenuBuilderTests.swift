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
        return (buildMenu(registry: registry), registry)
    }

    private func buildMenu(registry: FeatureRegistry) -> NSMenu {
        let target = MenuTarget()
        return MenuBuilder.build(
            registry: registry,
            loginItemEnabled: false,
            missingPermission: registry.missingPermissionFeatures(),
            actions: MenuActions(
                onToggle: { _ in .disabled },
                onRunAction: { _ in },
                onShowOnboarding: {},
                onHelp: {},
                onPreferences: {},
                onLaunchAtLogin: { false },
                onQuit: {}
            ),
            target: target
        )
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
        let menuAfter = buildMenu(registry: registry)
        XCTAssertEqual(menuAfter.items[0].state, .on)
    }

    func testMissingPermissionWarning() {
        // Persist an AX-gated feature while permission is missing.
        let (menu, registry) = makeMenu(granted: true)
        _ = registry.setEnabled(true, for: .scrollVim)
        XCTAssertEqual(menu.items.count, 12)
        let denied = FeatureRegistry(
            features: StubFeature.makeDefaults(),
            store: persistedStore(from: registry),
            isAccessibilityGranted: { false }
        )
        let warned = buildMenu(registry: denied)
        // 12 + warning + separator.
        XCTAssertEqual(warned.items.count, 14)
        XCTAssertTrue(warned.items[7].title.hasPrefix("⚠️"))
    }

    /// Reopens the same persisted store in a new registry (simulates relaunch).
    private func persistedStore(from registry: FeatureRegistry) -> SettingsStore {
        // The registry under test shares its store's defaults suite; a fresh
        // store on the same suite sees the same persisted values. The suite
        // name is internal, so rebuild from the enabled set instead.
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        let enabled = FeatureCatalog.all.map(\.id).filter { registry.isEnabled($0) }
        store.update { $0.enabled = Set(enabled) }
        return store
    }
}
