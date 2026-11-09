// SPDX-License-Identifier: MIT
// Keep Awake: prevents display/system idle sleep via an IOPM assertion.

import AppKit
import IOKit
import IOKit.pwr_mgt
import ToolboxCore

/// Holds an IOPM power assertion while running. Releasing it (or process
/// death, which releases it in the kernel) ends the effect.
final class KeepAwakeFeature: NSObject, StatefulFeature {
    static let descriptor = FeatureDescriptor(
        id: .keepAwake,
        titleKey: "Keep Awake",
        kind: .toggle,
        requiredPermissions: [],
        menuOrder: 1
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    var onChange: (() -> Void)?
    /// Fired when a chosen duration elapses; the controller unchecks the toggle.
    var onExpired: (() -> Void)?

    private(set) var isRunning = false

    private let store: SettingsStore
    private var assertionID: IOPMAssertionID = 0
    private var releaseTimer: Timer?
    private var durations: [(title: String, seconds: TimeInterval?)] {
        [
            (NSLocalizedString("Indefinite", comment: ""), nil),
            (NSLocalizedString("15 min", comment: ""), 15 * 60),
            (NSLocalizedString("1 h", comment: ""), 3600),
            (NSLocalizedString("2 h", comment: ""), 7200),
        ]
    }

    init(store: SettingsStore) {
        self.store = store
        super.init()
    }

    func start() throws {
        if assertionID != 0 {
            isRunning = true
            return
        }
        let name = "Toolbox: Keep Awake" as CFString
        let typeName: String = store.settings.keepAwake.allowDisplaySleep
            ? kIOPMAssertionTypePreventUserIdleSystemSleep
            : kIOPMAssertionTypePreventUserIdleDisplaySleep
        let type = typeName as CFString
        var newID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &newID
        )
        guard result == kIOReturnSuccess else { return }
        assertionID = newID
        isRunning = true
        scheduleRelease()
        onChange?()
    }

    func stop() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        isRunning = false
        onChange?()
    }

    private func scheduleRelease() {
        releaseTimer?.invalidate()
        releaseTimer = nil
        guard let duration = store.settings.keepAwake.defaultDuration else { return }
        releaseTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.onExpired?()
        }
    }

    // MARK: - Submenu

    func makeSubmenu() -> NSMenu? {
        let menu = NSMenu()
        if isRunning {
            let info = NSMenuItem(title: remainingTitle(), action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            menu.addItem(.separator())
        }
        for (title, seconds) in durations {
            let item = NSMenuItem(title: title, action: #selector(pickDuration(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = seconds as NSNumber?
            let current = store.settings.keepAwake.defaultDuration
            item.state = (current == seconds) ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func remainingTitle() -> String {
        if let fireDate = releaseTimer?.fireDate {
            let minutes = max(1, Int(ceil(fireDate.timeIntervalSinceNow / 60)))
            let template = NSLocalizedString("Active — %ld min left", comment: "")
            return String.localizedStringWithFormat(template, minutes)
        }
        return NSLocalizedString("Active", comment: "")
    }

    @objc private func pickDuration(_ sender: NSMenuItem) {
        let seconds = (sender.representedObject as? NSNumber)?.doubleValue
        store.update { $0.keepAwake.defaultDuration = seconds }
        if isRunning {
            scheduleRelease()
        }
        onChange?()
    }
}
