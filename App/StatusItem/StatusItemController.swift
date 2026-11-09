// SPDX-License-Identifier: MIT
// Owns the NSStatusItem and its menu. F1 replaces the static menu with one
// built from the FeatureRegistry catalog.

import AppKit

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()
        buildMenu()
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(
            systemSymbolName: "wrench.and.screwdriver",
            accessibilityDescription: "Toolbox"
        )
        image?.isTemplate = true
        button.image = image
    }

    private func buildMenu() {
        menu.removeAllItems()
        // F1: generate items from FeatureCatalog instead.
        let quitItem = NSMenuItem(
            title: String(localized: "Quit Toolbox", bundle: .main),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)
    }
}
