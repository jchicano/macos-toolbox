// SPDX-License-Identifier: MIT
// Brief non-activating confirmation toast ("Copied …").

import AppKit

/// Shows a small floating confirmation for ~1.2 s.
enum HudToast {
    private static var panel: NSPanel?
    private static var timer: Timer?

    static func show(text: String) {
        timer?.invalidate()
        panel?.orderOut(nil)
        let label = NSTextField(labelWithString: text)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 44))
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),
        ])
        let toast = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        toast.contentView = content
        toast.backgroundColor = NSColor(white: 0.15, alpha: 0.92)
        toast.isOpaque = false
        toast.hasShadow = true
        toast.level = .floating
        toast.center()
        toast.orderFrontRegardless()
        panel = toast
        timer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            panel?.orderOut(nil)
            panel = nil
        }
    }
}
