// SPDX-License-Identifier: MIT
// Breaks: work timer with idle pause, notifications and optional overlay.

import AppKit
import ToolboxCore
import UserNotifications

private enum BreakNotification {
    static let category = "toolbox.breaks"
    static let dueID = "toolbox.breaks.due"
    static let actionStart = "toolbox.breaks.start"
    static let actionSnooze = "toolbox.breaks.snooze"
    static let actionSkip = "toolbox.breaks.skip"
}

/// Forwards notification responses to the feature (center.delegate is weak).
private final class BreakNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    weak var feature: BreaksFeature?

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        switch response.actionIdentifier {
        case BreakNotification.actionSnooze, UNNotificationDefaultActionIdentifier:
            feature?.snooze()
        case BreakNotification.actionStart:
            feature?.beginBreak()
        case BreakNotification.actionSkip:
            feature?.skip()
        default:
            break
        }
    }
}

final class BreaksFeature: NSObject, StatefulFeature {
    static let descriptor = FeatureDescriptor(
        id: .breaks,
        titleKey: "Breaks",
        kind: .toggle,
        requiredPermissions: [],
        menuOrder: 0
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    var onChange: (() -> Void)?
    private(set) var isRunning = false

    private let store: SettingsStore
    private let center = UNUserNotificationCenter.current()
    private lazy var delegate = BreakNotificationDelegate()
    private var scheduler: BreakScheduler
    private var pollTimer: Timer?
    private var sleepStart: Date?
    private var lastDisplayedMinute: Int?

    private static let pollInterval: TimeInterval = 30

    init(store: SettingsStore) {
        self.store = store
        scheduler = BreakScheduler(
            workSeconds: TimeInterval(store.settings.breaks.workMinutes * 60),
            breakSeconds: TimeInterval(store.settings.breaks.breakMinutes * 60),
            idleResetSeconds: TimeInterval(store.settings.breaks.idleResetMinutes * 60)
        )
        super.init()
        delegate.feature = self
    }

    func start() throws {
        guard !isRunning else { return }
        refreshScheduler()
        scheduler.start()
        lastDisplayedMinute = nil

        let start = UNNotificationAction(
            identifier: BreakNotification.actionStart,
            title: NSLocalizedString("Start Break", comment: "")
        )
        let snooze = UNNotificationAction(
            identifier: BreakNotification.actionSnooze,
            title: NSLocalizedString("Snooze 5 min", comment: "")
        )
        let skip = UNNotificationAction(
            identifier: BreakNotification.actionSkip,
            title: NSLocalizedString("Skip", comment: "")
        )
        let category = UNNotificationCategory(
            identifier: BreakNotification.category,
            actions: [start, snooze, skip],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        observeSleep(true)
        isRunning = true
        onChange?()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        observeSleep(false)
        center.removePendingNotificationRequests(withIdentifiers: [BreakNotification.dueID])
        center.removeDeliveredNotifications(withIdentifiers: [BreakNotification.dueID])
        overlay.hide()
        isRunning = false
        onChange?()
    }

    // MARK: - Sampling

    private func refreshScheduler() {
        scheduler.workSeconds = TimeInterval(store.settings.breaks.workMinutes * 60)
        scheduler.breakSeconds = TimeInterval(store.settings.breaks.breakMinutes * 60)
        scheduler.idleResetSeconds = TimeInterval(store.settings.breaks.idleResetMinutes * 60)
    }

    private func tick() {
        guard isRunning else { return }
        refreshScheduler()
        let idle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        if scheduler.sample(idleSeconds: idle) {
            fireBreak()
        }
        // Refresh the "next break in N min" item only when the minute changes,
        // so the menu is not rebuilt under the user's cursor.
        let minute = Int(ceil(scheduler.remaining / 60))
        if minute != lastDisplayedMinute {
            lastDisplayedMinute = minute
            onChange?()
        }
    }

    private func fireBreak() {
        let minutes = store.settings.breaks.breakMinutes
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("Time for a break", comment: "")
        let template = NSLocalizedString("Time to stretch — %ld min", comment: "")
        content.body = String.localizedStringWithFormat(template, minutes) + " ☕"
        content.categoryIdentifier = BreakNotification.category
        if store.settings.breaks.sound {
            content.sound = .default
        }
        let request = UNNotificationRequest(
            identifier: BreakNotification.dueID,
            content: content,
            trigger: nil
        )
        center.add(request)
        if store.settings.breaks.overlay {
            overlay.show(
                minutes: minutes,
                onSkip: { [weak self] in self?.skip() },
                onSnooze: { [weak self] in self?.snooze() }
            )
        }
        onChange?()
    }

    // MARK: - Actions (menu, notifications, overlay)

    func takeBreakNow() {
        fireBreak()
        scheduler.startBreak()
        lastDisplayedMinute = nil
        onChange?()
    }

    func snooze() {
        overlay.hide()
        scheduler.snooze(seconds: 5 * 60)
        center.removeDeliveredNotifications(withIdentifiers: [BreakNotification.dueID])
        lastDisplayedMinute = nil
        onChange?()
    }

    func skip() {
        overlay.hide()
        scheduler.skip()
        center.removeDeliveredNotifications(withIdentifiers: [BreakNotification.dueID])
        lastDisplayedMinute = nil
        onChange?()
    }

    func beginBreak() {
        scheduler.startBreak()
        center.removeDeliveredNotifications(withIdentifiers: [BreakNotification.dueID])
        if store.settings.breaks.overlay {
            // Keep the overlay visible for the break duration.
        } else {
            overlay.hide()
        }
        lastDisplayedMinute = nil
        onChange?()
    }

    // MARK: - Sleep / lock handling

    private func observeSleep(_ observe: Bool) {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        if observe {
            workspaceCenter.addObserver(self, selector: #selector(screenSlept), name: NSWorkspace.screensDidSleepNotification, object: nil)
            workspaceCenter.addObserver(self, selector: #selector(screenWoke), name: NSWorkspace.screensDidWakeNotification, object: nil)
            distributed.addObserver(self, selector: #selector(screenSlept), name: .init("com.apple.screenIsLocked"), object: nil)
            distributed.addObserver(self, selector: #selector(screenWoke), name: .init("com.apple.screenIsUnlocked"), object: nil)
        } else {
            workspaceCenter.removeObserver(self)
            distributed.removeObserver(self)
        }
    }

    @objc private func screenSlept() {
        sleepStart = Date()
    }

    @objc private func screenWoke() {
        defer { sleepStart = nil }
        guard isRunning, let start = sleepStart else { return }
        let gap = Date().timeIntervalSince(start)
        if scheduler.sample(idleSeconds: gap) {
            fireBreak()
        }
    }

    // MARK: - Submenu

    private let overlay = BreakOverlayController()
    private let intervals = [25, 50, 60, 90]

    func makeSubmenu() -> NSMenu? {
        let menu = NSMenu()
        let info = NSMenuItem(title: nextBreakTitle(), action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)
        let now = NSMenuItem(title: NSLocalizedString("Take a Break Now", comment: ""), action: #selector(takeBreakNowItem(_:)), keyEquivalent: "")
        now.target = self
        menu.addItem(now)
        menu.addItem(.separator())

        let intervalItem = NSMenuItem(title: NSLocalizedString("Interval", comment: ""), action: nil, keyEquivalent: "")
        let intervalMenu = NSMenu()
        for minutes in intervals {
            let template = NSLocalizedString("%ld min", comment: "")
            let item = NSMenuItem(
                title: String.localizedStringWithFormat(template, minutes),
                action: #selector(pickInterval(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = minutes as NSNumber
            item.state = (store.settings.breaks.workMinutes == minutes) ? .on : .off
            intervalMenu.addItem(item)
        }
        intervalItem.submenu = intervalMenu
        menu.addItem(intervalItem)
        return menu
    }

    private func nextBreakTitle() -> String {
        if scheduler.isDue {
            return NSLocalizedString("Break due — take a break", comment: "")
        }
        let template = NSLocalizedString("Next break in %ld min", comment: "")
        return String.localizedStringWithFormat(template, max(1, Int(ceil(scheduler.remaining / 60))))
    }

    @objc private func takeBreakNowItem(_: NSMenuItem) {
        takeBreakNow()
    }

    @objc private func pickInterval(_ sender: NSMenuItem) {
        guard let minutes = (sender.representedObject as? NSNumber)?.intValue else { return }
        store.update { $0.breaks.workMinutes = minutes }
        refreshScheduler()
        lastDisplayedMinute = nil
        onChange?()
    }
}
