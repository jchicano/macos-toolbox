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
        // 5 features + separator + Help + Preferences + Launch at Login + separator + Quit.
        XCTAssertEqual(menu.items.count, 11)
        let expected = ["Breaks", "Keep Awake", "Auto-close", "Snippets", "Color Picker"]
        for (index, title) in expected.enumerated() {
            XCTAssertTrue(menu.items[index].title.hasPrefix(title), "item \(index)")
        }
        XCTAssertTrue(menu.items[5].isSeparatorItem)
        XCTAssertEqual(menu.items[6].title, "Help")
        XCTAssertEqual(menu.items[7].title, "Preferences…")
        XCTAssertEqual(menu.items[8].title, "Launch at Login")
        XCTAssertTrue(menu.items[9].isSeparatorItem)
        XCTAssertEqual(menu.items[10].title, "Quit Toolbox")
    }

    func testToggleStateFollowsRegistry() {
        let (menuBefore, registry) = makeMenu()
        XCTAssertEqual(menuBefore.items[0].state, .off)
        _ = registry.setEnabled(true, for: .breaks)
        let menuAfter = buildMenu(registry: registry)
        XCTAssertEqual(menuAfter.items[0].state, .on)
    }

    func testToggleWithSubmenuExposesEnabledItem() {
        let store = SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
        let feature = SubmenuToggleFeature()
        let registry = FeatureRegistry(
            features: [feature],
            store: store,
            isAccessibilityGranted: { true }
        )
        var toggled: FeatureID?
        let target = MenuTarget()
        let actions = MenuActions(
            onToggle: { toggled = $0; return .enabled },
            onRunAction: { _ in },
            onShowOnboarding: {},
            onHelp: {},
            onPreferences: {},
            onLaunchAtLogin: { false },
            onQuit: {}
        )
        let menu = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: false,
            missingPermission: [],
            actions: actions,
            target: target
        )
        let item = menu.items.first { ($0.representedObject as? String) == FeatureID.keepAwake.rawValue }
        let first = item?.submenu?.items.first
        XCTAssertEqual(first?.title, "Enabled")
        XCTAssertEqual(first?.state, .off)
        XCTAssertNotNil(first?.action)
        XCTAssertTrue(first?.target === target)
        XCTAssertEqual(first?.representedObject as? String, FeatureID.keepAwake.rawValue)

        // AppKit sends this action from the submenu entry, not from the parent.
        target.toggle(first!)
        XCTAssertEqual(toggled, .keepAwake)

        _ = registry.setEnabled(true, for: .keepAwake)
        let rebuiltMenu = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: false,
            missingPermission: [],
            actions: actions,
            target: target
        )
        let rebuiltItem = rebuiltMenu.items.first { ($0.representedObject as? String) == FeatureID.keepAwake.rawValue }
        XCTAssertEqual(rebuiltItem?.submenu?.items.first?.state, .on)
    }

    func testMissingPermissionWarning() {
        // Persist an AX-gated feature while permission is missing.
        let (menu, registry) = makeMenu(granted: true)
        _ = registry.setEnabled(true, for: .autoClose)
        XCTAssertEqual(menu.items.count, 11)
        let denied = FeatureRegistry(
            features: StubFeature.makeDefaults(),
            store: persistedStore(from: registry),
            isAccessibilityGranted: { false }
        )
        let warned = buildMenu(registry: denied)
        // 11 + warning + separator.
        XCTAssertEqual(warned.items.count, 13)
        XCTAssertTrue(warned.items[6].title.hasPrefix("⚠️"))
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

/// Toggle feature with a submenu, like Keep Awake, Snippets and Breaks.
private final class SubmenuToggleFeature: Feature {
    static let descriptor = FeatureCatalog.descriptor(for: .keepAwake)!
    private(set) var isRunning = false

    func start() throws { isRunning = true }
    func stop() { isRunning = false }

    func makeSubmenu() -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(withTitle: "1 h", action: nil, keyEquivalent: "")
        return menu
    }
}
