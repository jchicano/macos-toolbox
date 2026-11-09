// SPDX-License-Identifier: MIT
// Builds the menu bar menu from the feature catalog and registry state.

import AppKit
import ToolboxCore

/// Callbacks from menu items back to the owning controller.
struct MenuActions {
    var onToggle: (FeatureID) -> ToggleResult
    var onRunAction: (FeatureID) -> Void
    var onShowOnboarding: () -> Void
    var onHelp: () -> Void
    var onPreferences: () -> Void
    var onLaunchAtLogin: () -> Bool
    var onQuit: () -> Void
}

/// Target object kept alive by the builder for menu item actions.
final class MenuTarget: NSObject {
    var actions: MenuActions?

    @objc func toggle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = FeatureID(rawValue: raw)
        else { return }
        _ = actions?.onToggle(id)
    }

    @objc func runAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let id = FeatureID(rawValue: raw)
        else { return }
        actions?.onRunAction(id)
    }

    @objc func showOnboarding(_: NSMenuItem) { actions?.onShowOnboarding() }

    @objc func help(_: NSMenuItem) { actions?.onHelp() }
    @objc func preferences(_: NSMenuItem) { actions?.onPreferences() }
    @objc func launchAtLogin(_: NSMenuItem) { _ = actions?.onLaunchAtLogin() }
    @objc func quit(_: NSMenuItem) { actions?.onQuit() }
}

enum MenuBuilder {
    /// Builds a fresh menu. The controller rebuilds on every registry change.
    static func build(
        registry: FeatureRegistry,
        loginItemEnabled: Bool,
        missingPermission: [FeatureDescriptor],
        actions: MenuActions,
        target: MenuTarget
    ) -> NSMenu {
        target.actions = actions
        let menu = NSMenu()

        for descriptor in FeatureCatalog.all {
            let feature = registry.feature(for: descriptor.id)
            let fallback = NSLocalizedString(descriptor.titleKey, comment: "")
            let item = NSMenuItem(title: feature?.menuTitle ?? fallback, action: nil, keyEquivalent: "")
            item.representedObject = descriptor.id.rawValue
            switch descriptor.kind {
            case .toggle:
                item.action = #selector(MenuTarget.toggle(_:))
                item.target = target
                item.state = registry.isEnabled(descriptor.id) ? .on : .off
                if let submenu = registry.feature(for: descriptor.id)?.makeSubmenu() {
                    menu.setSubmenu(submenu, for: item)
                }
            case .action:
                item.action = #selector(MenuTarget.runAction(_:))
                item.target = target
                if let submenu = registry.feature(for: descriptor.id)?.makeSubmenu() {
                    menu.setSubmenu(submenu, for: item)
                }
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())

        if !missingPermission.isEmpty {
            let warning = NSMenuItem(
                title: NSLocalizedString("⚠️ Accessibility permission required…", comment: ""),
                action: #selector(MenuTarget.showOnboarding(_:)),
                keyEquivalent: ""
            )
            warning.target = target
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        let help = NSMenuItem(
            title: NSLocalizedString("Help", comment: ""),
            action: #selector(MenuTarget.help(_:)),
            keyEquivalent: ""
        )
        help.target = target
        menu.addItem(help)

        let preferences = NSMenuItem(
            title: NSLocalizedString("Preferences…", comment: ""),
            action: #selector(MenuTarget.preferences(_:)),
            keyEquivalent: ","
        )
        preferences.target = target
        menu.addItem(preferences)

        let loginItem = NSMenuItem(
            title: NSLocalizedString("Launch at Login", comment: ""),
            action: #selector(MenuTarget.launchAtLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = target
        loginItem.state = loginItemEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: NSLocalizedString("Quit Toolbox", comment: ""),
            action: #selector(MenuTarget.quit(_:)),
            keyEquivalent: "q"
        )
        quit.target = target
        menu.addItem(quit)

        return menu
    }
}
