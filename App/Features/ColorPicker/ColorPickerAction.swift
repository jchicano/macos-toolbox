// SPDX-License-Identifier: MIT
// Color picker: native loupe, sRGB conversion, clipboard, recents and HUD.
// NSColorSampler needs no Screen Recording permission.

import AppKit
import ToolboxCore
import os

private let pickLog = OSLog(subsystem: "com.jchicano.toolbox", category: "colorpicker")

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
    /// Retained while the sampler is on screen: a temporary instance can be
    /// deallocated before AppKit presents the loupe, so nothing shows up.
    private var sampler: NSColorSampler?

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
        os_log("sampler requested", log: pickLog, type: .info)
        // The menu bar item does not activate the app; the sampler is a system
        // UI and needs an active app to present its overlay.
        NSApp.activate(ignoringOtherApps: true)
        let sampler = NSColorSampler()
        self.sampler = sampler
        sampler.show { [weak self] color in
            guard let self else { return }
            self.sampler = nil
            guard let color else {
                os_log("sampler cancelled", log: pickLog, type: .info)
                return
            }
            os_log("sampler returned a color", log: pickLog, type: .info)
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
        os_log("copied %{public}@", log: pickLog, type: .info, value)
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
        // AppKit does not send an item's action when it has a submenu, so the
        // sampler lives here as the first entry instead of on the parent item.
        let pick = NSMenuItem(
            title: NSLocalizedString("Pick Color…", comment: ""),
            action: #selector(pickColor(_:)),
            keyEquivalent: ""
        )
        pick.target = self
        menu.addItem(pick)
        menu.addItem(.separator())

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

    @objc private func pickColor(_: NSMenuItem) {
        pick()
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

    private func showHUD(value: String) {
        let template = NSLocalizedString("Copied %@", comment: "")
        HudToast.show(text: String.localizedStringWithFormat(template, value))
    }
}
