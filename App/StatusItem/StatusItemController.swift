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
    private let snippetStore: SnippetStore
    private let tracker = FrontmostAppTracker()
    private let focusCache: FocusedElementCache
    private let tapManager: EventTapManager
    #if DEBUG
    private let debugConsumer = DebugTapConsumer()
    #endif
    private let menuTarget = MenuTarget()
    private var cancellables = Set<AnyCancellable>()
    private var helpWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var pendingOnboardingID: FeatureID?
    private var didPromptForAccessibility = false
    private lazy var permissionMonitor = PermissionMonitor(
        isTrusted: PermissionsService.isAccessibilityTrusted,
        onGranted: { [weak self] in self?.permissionGranted() }
    )

    init(
        store: SettingsStore? = nil,
        registry: FeatureRegistry? = nil
    ) {
        let store = store ?? SettingsStore()
        self.store = store
        let snippetStore = SnippetStore()
        self.snippetStore = snippetStore
        focusCache = FocusedElementCache(tracker: tracker)
        tapManager = EventTapManager(tracker: tracker, focusCache: focusCache)
        #if DEBUG
        tapManager.addConsumer(debugConsumer)
        #endif
        let keepAwake = KeepAwakeFeature(store: store)
        let breaks = BreaksFeature(store: store)
        let autoClose = AutoCloseFeature(store: store, tapManager: tapManager, tracker: tracker, focusCache: focusCache)
        let snippets = SnippetsFeature(store: store, snippetStore: snippetStore, tapManager: tapManager, tracker: tracker, focusCache: focusCache)
        let registry = registry ?? FeatureRegistry(
            features: [
                breaks,
                keepAwake,
                autoClose,
                snippets,
                ColorPickerAction(store: store),
            ],
            store: store,
            isAccessibilityGranted: PermissionsService.isAccessibilityTrusted
        )
        self.registry = registry
        keepAwake.onExpired = { [weak registry] in
            _ = registry?.setEnabled(false, for: .keepAwake)
        }
        loginItems = LoginItemService(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        configureButton()

        tapManager.onPermissionLost = { [weak self] in
            // Permission revoked (or never granted): release everything now
            // instead of fighting the system by re-enabling the tap.
            // Persisted toggles stay; the menu shows the ⚠️ warning.
            self?.registry.stopAll()
            // A re-grant applies to this running process; watch for it so the
            // features resume without a relaunch.
            self?.watchForPermissionIfNeeded()
        }

        registry.restoreOnLaunch()
        loginItems.applyStored()
        rebuildMenu()
        resumeWhenPermissionIsGranted()

        // Rebuild the menu whenever the registry state changes.
        registry.$generation
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildMenu() }
            .store(in: &cancellables)
    }

    /// Stops every feature. Called from applicationWillTerminate.
    func shutdown() {
        permissionMonitor.stop()
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
            onToggle: { [weak self] id in self?.toggle(id) ?? .disabled },
            onRunAction: { [weak self] id in self?.registry.run(id) },
            onShowOnboarding: { [weak self] in self?.showOnboardingForMissing() },
            onHelp: { [weak self] in self?.showHelp() },
            onPreferences: { [weak self] in self?.showPreferences() },
            onLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLogin() ?? false },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        statusItem.menu = MenuBuilder.build(
            registry: registry,
            loginItemEnabled: loginItems.isEnabled,
            missingPermission: registry.missingPermissionFeatures(),
            actions: actions,
            target: menuTarget
        )
    }

    private func toggle(_ id: FeatureID) -> ToggleResult {
        let result = registry.setEnabled(!registry.isEnabled(id), for: id)
        if case .needsPermission = result {
            pendingOnboardingID = id
            showOnboarding(for: id)
        }
        return result
    }

    private func toggleLaunchAtLogin() -> Bool {
        let next = !loginItems.isEnabled
        try? loginItems.setEnabled(next)
        rebuildMenu()
        return loginItems.isEnabled
    }

    // MARK: - Accessibility onboarding

    private func onboardingTitle(for id: FeatureID) -> String {
        guard let descriptor = registry.descriptor(for: id) else { return "Toolbox" }
        return NSLocalizedString(descriptor.titleKey, comment: "")
    }

    private func showOnboardingForMissing() {
        if let first = registry.missingPermissionFeatures().first {
            pendingOnboardingID = first.id
            showOnboarding(for: first.id)
        }
    }

    private func showOnboarding(for id: FeatureID) {
        // Makes macOS add Toolbox to Privacy & Security › Accessibility by
        // itself, so the user only has to flip the switch (no "+" needed).
        promptForAccessibilityOnce()
        permissionMonitor.start()
        let view = PermissionOnboardingView(
            featureTitle: onboardingTitle(for: id),
            onGranted: { [weak self] in self?.onboardingGranted() },
            onDismiss: { [weak self] in self?.dismissOnboarding() }
        )
        if let window = onboardingWindow {
            window.contentViewController = NSHostingController(rootView: view)
        } else {
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Toolbox needs Accessibility permission", comment: "")
            window.styleMask = [.titled, .closable]
            window.center()
            onboardingWindow = window
        }
        onboardingWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func onboardingGranted() {
        permissionGranted()
    }

    /// Called as soon as Accessibility becomes available in the running app.
    /// Starts the feature the user asked for (if any) and every other persisted
    /// feature, so no relaunch or extra toggle is needed.
    private func permissionGranted() {
        permissionMonitor.stop()
        if let id = pendingOnboardingID {
            _ = registry.setEnabled(true, for: id)
        }
        closeOnboarding()
        registry.startPersistedFeatures()
        rebuildMenu()
    }

    /// The system prompt adds the app to the Accessibility list. At most once
    /// per launch, and never while running tests.
    private func promptForAccessibilityOnce() {
        guard !didPromptForAccessibility,
              !PermissionsService.isRunningTests,
              !PermissionsService.isAccessibilityTrusted() else { return }
        didPromptForAccessibility = true
        _ = PermissionsService.requestAccessibilityTrust()
    }

    /// Watches for a grant while persisted features are waiting for it
    /// (first launch, revoked permission, or a rebuild that invalidated the
    /// ad-hoc grant).
    private func resumeWhenPermissionIsGranted() {
        guard !PermissionsService.isRunningTests,
              !PermissionsService.isAccessibilityTrusted(),
              !registry.missingPermissionFeatures().isEmpty else { return }
        promptForAccessibilityOnce()
        permissionMonitor.start()
    }

    private func closeOnboarding() {
        pendingOnboardingID = nil
        onboardingWindow?.close()
    }

    /// "Not Now": stop polling unless some persisted feature is still waiting
    /// for the permission (then the menu warning keeps watching).
    private func dismissOnboarding() {
        closeOnboarding()
        if registry.missingPermissionFeatures().isEmpty {
            permissionMonitor.stop()
        }
    }

    /// Polls for a grant only while a persisted feature actually needs it.
    private func watchForPermissionIfNeeded() {
        guard !registry.missingPermissionFeatures().isEmpty else { return }
        permissionMonitor.start()
    }

    // MARK: - Help and Preferences (full versions land in F7)

    private func showHelp() {
        HelpInfo.refreshNotificationState()
        if helpWindow == nil {
            let view = HelpView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Toolbox Help", comment: "")
            window.styleMask = [.titled, .closable, .resizable]
            window.center()
            helpWindow = window
        }
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPreferences() {
        if preferencesWindow == nil {
            let view = PreferencesView(
                store: store,
                snippetStore: snippetStore,
                loginItems: loginItems,
                restartFeature: { [weak self] id in self?.registry.restart(id) }
            )
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = NSLocalizedString("Preferences", comment: "")
            window.styleMask = [.titled, .closable, .resizable]
            window.center()
            preferencesWindow = window
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
