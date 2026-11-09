// SPDX-License-Identifier: MIT
// Caches the focused element's role and the focused window's size for the
// frontmost app. Updated on the main thread via AXObserver; the tap callback
// only reads the cache (no AX calls, no I/O in the tap).

import AppKit
import Foundation

/// Coarse classification of the focused element.
enum FocusRole: Equatable {
    /// NSTextField, AXTextField and friends.
    case textInput
    /// Web content, terminals, lists, buttons… anything not text input.
    case other
    /// Unknown (no permission, non-AX app, lookup failed).
    case unknown
}

/// Snapshot read from any thread.
struct FocusSnapshot: Equatable {
    var role: FocusRole
    /// Size of the focused window, when readable. Used for half-page math.
    var windowSize: CGSize?
    /// Top-left origin of the focused window, when readable.
    var windowOrigin: CGPoint?
}

final class FocusedElementCache: NSObject {
    private let lock = NSLock()
    private var _snapshot = FocusSnapshot(role: .unknown, windowSize: nil)

    /// Latest snapshot. Safe from any thread.
    var snapshot: FocusSnapshot {
        get { lock.synchronized { _snapshot } }
    }

    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var refreshTimer: Timer?
    private let tracker: FrontmostAppTracker

    init(tracker: FrontmostAppTracker) {
        self.tracker = tracker
        super.init()
    }

    /// Starts observing (call when the tap installs).
    func activate() {
        guard refreshTimer == nil else { return }
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        reobserve()
        // Fallback for apps that never fire the focused-element notification.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// Stops observing and clears the cache (call when the tap is destroyed).
    func deactivate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        detachObserver()
        lock.synchronized { _snapshot = FocusSnapshot(role: .unknown, windowSize: nil, windowOrigin: nil) }
    }

    @objc private func activeAppChanged(_ notification: Notification) {
        reobserve()
    }

    private func reobserve() {
        detachObserver()
        refresh()
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let pid = app.processIdentifier
        var observer: AXObserver?
        let result = AXObserverCreate(pid, axCallback, &observer)
        guard result == .success, let observer else { return }
        self.observer = observer
        observedPID = pid
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        AXObserverAddNotification(
            observer,
            appElement,
            kAXFocusedUIElementChangedNotification as CFString,
            refcon
        )
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func detachObserver() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedPID = 0
    }

    /// Reads the focused role + window frame off the tap path (main thread).
    func refresh() {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            store(FocusSnapshot(role: .unknown, windowSize: nil, windowOrigin: nil))
            return
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focusedElement = focused as! AXUIElement?
        else {
            store(FocusSnapshot(role: .unknown, windowSize: nil, windowOrigin: nil))
            return
        }
        var roleValue: CFTypeRef?
        let role: FocusRole
        if AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleValue) == .success,
           let roleString = roleValue as? String
        {
            role = Self.classify(role: roleString, element: focusedElement)
        } else {
            role = .unknown
        }
        let (windowSize, windowOrigin) = Self.focusedWindowFrame(appElement: appElement)
        store(FocusSnapshot(role: role, windowSize: windowSize, windowOrigin: windowOrigin))
    }

    private static func classify(role: String, element: AXUIElement) -> FocusRole {
        switch role {
        case kAXTextFieldRole as String,
             kAXTextAreaRole as String,
             kAXComboBoxRole as String:
            return .textInput
        case kAXStaticTextRole as String:
            return .other
        default:
            // Search fields expose AXSearchField in the subrole.
            var subrole: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
               let subroleString = subrole as? String,
               subroleString == (kAXSearchFieldSubrole as String)
            {
                return .textInput
            }
            return .other
        }
    }

    private static func focusedWindowFrame(appElement: AXUIElement) -> (CGSize?, CGPoint?) {
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let windowElement = window as! AXUIElement?
        else { return (nil, nil) }
        var size = CGSize.zero
        var origin = CGPoint.zero
        var gotSize = false
        var gotOrigin = false
        if let sizeValue = windowElement.sizeValue(forAttribute: kAXSizeAttribute as CFString),
           AXValueGetValue(sizeValue, .cgSize, &size)
        {
            gotSize = true
        }
        if let originValue = windowElement.sizeValue(forAttribute: kAXPositionAttribute as CFString),
           AXValueGetValue(originValue, .cgPoint, &origin)
        {
            gotOrigin = true
        }
        return (gotSize ? size : nil, gotOrigin ? origin : nil)
    }

    private func store(_ snapshot: FocusSnapshot) {
        lock.synchronized { _snapshot = snapshot }
    }
}

private func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    // Runs on the main runloop (the observer's source was added there).
    guard let refcon else { return }
    let cache = Unmanaged<FocusedElementCache>.fromOpaque(refcon).takeUnretainedValue()
    cache.refresh()
}

private extension AXUIElement {
    func sizeValue(forAttribute attribute: CFString) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute, &value) == .success else { return nil }
        return (value as! AXValue?)
    }
}

private extension NSLock {
    func synchronized<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
