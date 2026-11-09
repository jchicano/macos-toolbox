// SPDX-License-Identifier: MIT
// Vim Scroll: Ctrl+D / Ctrl+U scroll half a page in the frontmost app.

import AppKit
import CoreGraphics
import ToolboxCore

/// Consumes Ctrl+D (down) and Ctrl+U (up) and posts a pixel half-page scroll.
/// Skips terminals/editors (filter), Cocoa text fields (forward-delete must
/// survive), and any combination with extra modifiers.
final class ScrollVimFeature: NSObject, TapConsumer, StatefulFeature {
    static let descriptor = FeatureDescriptor(
        id: .scrollVim,
        titleKey: "Vim Scroll",
        kind: .toggle,
        requiredPermissions: [.accessibility],
        menuOrder: 2
    )

    var descriptor: FeatureDescriptor { Self.descriptor }
    var onChange: (() -> Void)?
    let tapPriority = 30
    private(set) var isRunning = false

    private let store: SettingsStore
    private let tapManager: EventTapManager
    private let frontmostBundleID: () -> String?
    private let focusSnapshot: () -> FocusSnapshot

    /// Posts a computed scroll. Overridden in tests to capture without posting.
    var poster: (ScrollRequest) -> Void = { request in
        ScrollPoster.scroll(pixels: request.pixels, smooth: request.smooth, at: request.location)
    }

    /// ANSI keycodes.
    private enum Key {
        static let d: CGKeyCode = 0x02
        static let u: CGKeyCode = 0x20
    }

    private static let fallbackHeight: CGFloat = 400

    init(
        store: SettingsStore,
        tapManager: EventTapManager,
        frontmostBundleID: @escaping () -> String?,
        focusSnapshot: @escaping () -> FocusSnapshot
    ) {
        self.store = store
        self.tapManager = tapManager
        self.frontmostBundleID = frontmostBundleID
        self.focusSnapshot = focusSnapshot
        super.init()
    }

    /// Convenience wiring for production (tracker + cache).
    convenience init(store: SettingsStore, tapManager: EventTapManager, tracker: FrontmostAppTracker, focusCache: FocusedElementCache) {
        self.init(
            store: store,
            tapManager: tapManager,
            frontmostBundleID: { tracker.frontmostBundleID },
            focusSnapshot: { focusCache.snapshot }
        )
    }

    func start() throws {
        guard PermissionsService.isAccessibilityTrusted() else {
            throw FeatureError.permissionMissing(.accessibility)
        }
        tapManager.addConsumer(self)
        isRunning = true
        onChange?()
    }

    func stop() {
        tapManager.removeConsumer(self)
        isRunning = false
        onChange?()
    }

    func handle(event: CGEvent, type: CGEventType) -> TapResult {
        guard type == .keyDown else { return .pass }
        guard store.settings.scrollVim.filter.allows(frontmostBundleID()) else { return .pass }
        let relevant = event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        guard relevant == .maskControl else { return .pass }
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == Key.d || keyCode == Key.u else { return .pass }
        let snapshot = focusSnapshot()
        if store.settings.scrollVim.skipTextFields, snapshot.role == .textInput {
            return .pass
        }
        let settings = store.settings.scrollVim
        let height = snapshot.windowSize?.height ?? Self.fallbackHeight
        let magnitude = Int((height * CGFloat(settings.fraction)).rounded())
        guard magnitude > 0 else { return .pass }
        // Wheel positive scrolls up; Ctrl+D goes down.
        let delta = (keyCode == Key.d) ? -magnitude : magnitude
        let center: CGPoint? = {
            guard let origin = snapshot.windowOrigin, let size = snapshot.windowSize else { return nil }
            return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        }()
        poster(ScrollRequest(pixels: delta, smooth: settings.smooth, location: center))
        return .consume
    }
}

/// A computed scroll: pixel delta (negative = down), smoothing and target.
struct ScrollRequest: Equatable {
    var pixels: Int
    var smooth: Bool
    var location: CGPoint?
}
