// SPDX-License-Identifier: MIT
// Color picker: native loupe, sRGB conversion, clipboard, recents and HUD.
// NSColorSampler needs no Screen Recording permission.

import AppKit
import ToolboxCore

/// Momentary action feature: every run opens the sampler once.
final class ColorPickerAction: NSObject, Feature {
    static let descriptor = FeatureDescriptor(
        id: .colorPicker,
        titleKey: "Color Picker",
        kind: .action,
        requiredPermissions: [],
        menuOrder: 5
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    private(set) var isRunning = false

    private let store: SettingsStore
    private var hudTimer: Timer?
    private var hudPanel: NSPanel?

    init(store: SettingsStore) {
        self.store = store
        super.init()
    }

    func start() throws {
        pick()
    }

    func stop() {
        // Nothing persistent: sampling either finished or was cancelled.
    }

    private func pick() {
        NSColorSampler().show { [weak self] color in
            guard let self, let color else { return }
            self.copy(color: color)
        }
    }

    private func copy(color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return }
        let rgb = SRGBColor(
            red: Double(srgb.redComponent),
            green: Double(srgb.greenComponent),
            blue: Double(srgb.blueComponent)
        )
        let value = rgb.formatted(
            as: store.settings.colorPicker.format,
            uppercaseHex: store.settings.colorPicker.uppercase
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        store.update { settings in
            var recents = settings.colorPicker.recents
            if recents.first != value {
                recents.removeAll { $0 == value }
                recents.insert(value, at: 0)
                settings.colorPicker.recents = Array(recents.prefix(10))
            }
        }
        showHUD(value: value)
    }

    // MARK: - Submenu

    func makeSubmenu() -> NSMenu? {
        let menu = NSMenu()
        let formatItem = NSMenuItem(title: NSLocalizedString("Format", comment: ""), action: nil, keyEquivalent: "")
        let formatMenu = NSMenu()
        let formats: [(ColorFormat, String)] = [
            (.hex, "HEX"),
            (.rgb, "rgb()"),
            (.hsl, "hsl()"),
            (.swiftUI, "SwiftUI Color"),
            (.nsColor, "NSColor"),
        ]
        for (format, title) in formats {
            let item = NSMenuItem(title: title, action: #selector(pickFormat(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = format.rawValue
            item.state = (store.settings.colorPicker.format == format) ? .on : .off
            formatMenu.addItem(item)
        }
        formatItem.submenu = formatMenu
        menu.addItem(formatItem)

        let recents = store.settings.colorPicker.recents
        if !recents.isEmpty {
            let recentsItem = NSMenuItem(title: NSLocalizedString("Recent", comment: ""), action: nil, keyEquivalent: "")
            let recentsMenu = NSMenu()
            for value in recents {
                let item = NSMenuItem(title: value, action: #selector(copyRecent(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = value as NSString
                item.image = swatchImage(hex: value)
                recentsMenu.addItem(item)
            }
            recentsItem.submenu = recentsMenu
            menu.addItem(recentsItem)
        }
        return menu
    }

    @objc private func pickFormat(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let format = ColorFormat(rawValue: raw)
        else { return }
        store.update { $0.colorPicker.format = format }
    }

    @objc private func copyRecent(_ sender: NSMenuItem) {
        guard let value = sender.representedObject as? String else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        showHUD(value: value)
    }

    private func swatchImage(hex: String) -> NSImage? {
        // Parse #RRGGBB for the swatch; skip the image when unparseable.
        guard hex.hasPrefix("#"), hex.count == 7 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: String(hex.dropFirst())).scanHexInt64(&rgb) else { return nil }
        let color = NSColor(
            srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - HUD

    private func showHUD(value: String) {
        hudTimer?.invalidate()
        hudPanel?.orderOut(nil)
        let template = NSLocalizedString("Copied %@", comment: "")
        let label = NSTextField(labelWithString: String.localizedStringWithFormat(template, value))
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 44))
        content.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = content
        panel.backgroundColor = NSColor(white: 0.15, alpha: 0.92)
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.center()
        panel.orderFrontRegardless()
        hudPanel = panel
        hudTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            self?.hudPanel?.orderOut(nil)
            self?.hudPanel = nil
        }
    }
}
