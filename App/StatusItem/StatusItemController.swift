// SPDX-License-Identifier: MIT
// Owns the NSStatusItem. The menu is rebuilt from the catalog on every change.

import AppKit
import Combine
import SwiftUI
import ToolboxCore

final class StatusItemController {
    private let statusItem: NSStatusItem
    private let store: SettingsStore
    private let registry: FeatureRegistry
    private let loginItems: LoginItemService
    private let menuTarget = MenuTarget()
    private var cancellables = Set<AnyCancellable>()
    private var helpWindow: NSWindow?
    private var preferencesWindow: NSWindow?

    init(
        store: SettingsStore? = nil,
        registry: FeatureRegistry? = nil
    ) {
        let store = store ?? SettingsStore()
        self.store = store
        let registry = registry ?? FeatureRegistry(
            features: StubFeature.makeDefaults(),
            store: store,
            isAccessibilityGranted: PermissionCheck.isAccessibilityGranted
        )
        self.registry = registry
        loginItems = LoginItemService(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()

        registry.restoreOnLaunch()
        loginItems.applyStored()
        rebuildMenu()

        // Rebuild the menu whenever the registry state changes.
        registry.$generation
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    /// Stops every feature. Called from applicationWillTerminate.
    func shutdown() {
        registry.stopAll()
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

    private func rebuildMenu() {
        let actions = MenuActions(
            onToggle: { [weak self] id in self?.registry.setEnabled(!(self?.registry.isEnabled(id) ?? false), for: id) ?? .disabled },
            onRunAction: { [weak self] id in self?.registry.run(id) },
            onHelp: { [weak self] in self?.showHelp() },
            onPreferences: { [weak self] in self?.showPreferences() },
            onLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() ?? false },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        statusItem.menu = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: loginItems.isEnabled,
            actions: actions,
            target: menuTarget
        )
    }

    private func toggleLaunchAtLogin() -> Bool {
        let next = !loginItems.isEnabled
        try? loginItems.setEnabled(next)
        rebuildMenu()
        return loginItems.isEnabled
    }

    // MARK: - Windows (full versions land in F3/F7)

    private func showHelp() {
        if helpWindow == nil {
            let view = HelpView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Toolbox Help", comment: "")
            window.styleMask = [.titled, .closable]
            window.center()
            helpWindow = window
        }
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesPlaceholderView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Preferences", comment: "")
            window.styleMask = [.titled, .closable]
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
