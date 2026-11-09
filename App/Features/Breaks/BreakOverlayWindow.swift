// SPDX-License-Identifier: MIT
// Soft full-screen break overlay (opt-in): countdown with Skip and Snooze.

import AppKit
import ObjectiveC

/// Translucent window on every screen. Never grabs the keyboard.
final class BreakOverlayController {
    private var windows: [NSWindow] = []
    private var countdownTimer: Timer?
    private var endsAt: Date?
    private var countdownLabel: NSTextField?

    func show(minutes: Int, onSkip: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        hide()
        endsAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor(calibratedWhite: 0, alpha: 0.55)
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]
            window.ignoresMouseEvents = false

            let title = NSTextField(labelWithString: NSLocalizedString("Time for a break", comment: ""))
            title.font = .systemFont(ofSize: 34, weight: .semibold)
            title.textColor = .white
            title.alignment = .center

            let countdown = NSTextField(labelWithString: "")
            countdown.font = .monospacedDigitSystemFont(ofSize: 20, weight: .regular)
            countdown.textColor = .white
            countdown.alignment = .center
            countdownLabel = countdown

            let skipButton = NSButton(title: NSLocalizedString("Skip", comment: ""), target: nil, action: nil)
            skipButton.bezelStyle = .rounded
            let snoozeButton = NSButton(title: NSLocalizedString("Snooze 5 min", comment: ""), target: nil, action: nil)
            snoozeButton.bezelStyle = .rounded
            // Target-action via closures is unavailable on NSButton; use a helper row below.
            let row = NSStackView(views: [snoozeButton, skipButton])
            row.orientation = .horizontal
            row.alignment = .centerX
            row.spacing = 12

            let stack = NSStackView(views: [title, countdown, row])
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false

            let content = NSView(frame: screen.frame)
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            ])
            window.contentView = content
            let actions = OverlayActions(onSkip: onSkip, onSnooze: onSnooze, controller: self)
            skipButton.target = actions
            skipButton.action = #selector(OverlayActions.skip(_:))
            snoozeButton.target = actions
            snoozeButton.action = #selector(OverlayActions.snooze(_:))
            // Retain the helper alongside the window.
            objc_setAssociatedObject(window, "actions", actions, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            window.orderFrontRegardless()
            windows.append(window)
        }
        updateCountdown()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateCountdown()
        }
    }

    func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        countdownLabel = nil
    }

    private func updateCountdown() {
        guard let endsAt else { return }
        let remaining = max(0, Int(endsAt.timeIntervalSinceNow))
        if remaining == 0 {
            hide()
            return
        }
        countdownLabel?.stringValue = String(format: "%d:%02d", remaining / 60, remaining % 60)
    }
}

/// Button target trampoline (NSButton needs @objc targets, not closures).
private final class OverlayActions: NSObject {
    let onSkip: () -> Void
    let onSnooze: () -> Void
    weak var controller: BreakOverlayController?

    init(onSkip: @escaping () -> Void, onSnooze: @escaping () -> Void, controller: BreakOverlayController) {
        self.onSkip = onSkip
        self.onSnooze = onSnooze
        self.controller = controller
    }

    @objc func skip(_: NSButton) {
        controller?.hide()
        onSkip()
    }

    @objc func snooze(_: NSButton) {
        controller?.hide()
        onSnooze()
    }
}
