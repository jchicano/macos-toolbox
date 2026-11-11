// SPDX-License-Identifier: MIT
// One shared CGEventTap on its own thread, multiplexed to consumers.
// Installs only while at least one consumer is registered.

import CoreGraphics
import Foundation
import os

/// Consumer verdict for an event.
enum TapResult: Equatable {
    /// Let the event through untouched.
    case pass
    /// Swallow the event.
    case consume
    /// Swallow the original and post these (already marked synthetic).
    case replace([CGEvent])
}

/// A tap consumer. Lower priority runs first (Snippets → Auto-close).
/// handle runs on the tap thread: O(1), no AX, no I/O, no locks that block.
protocol TapConsumer: AnyObject {
    var tapPriority: Int { get }
    func handle(event: CGEvent, type: CGEventType) -> TapResult
}

private let tapLog = OSLog(subsystem: "com.jchicano.toolbox", category: "eventtap")

/// Owns the tap lifecycle. Thread-safe for add/remove; handle runs on the tap thread.
final class EventTapManager {
    /// Must match KeyPoster.mark.
    static let syntheticMark: Int64 = 0x544F4F4C // "TOOL"

    /// Injectable tap factory (tests substitute a stub).
    typealias TapFactory = (_ eventsOfInterest: CGEventMask, _ callback: CGEventTapCallBack, _ userInfo: UnsafeMutableRawPointer?) -> CFMachPort?

    private let lock = NSLock()
    private var _consumers: [any TapConsumer] = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var thread: TapThread?
    private let tracker: FrontmostAppTracker
    private let focusCache: FocusedElementCache
    private let tapFactory: TapFactory

    /// Test seam: synchronous tap handling without a real tap.
    /// Returns true when the event was swallowed (consumed or replaced).
    func testDispatch(type: CGEventType, event: CGEvent) -> Bool {
        dispatch(type: type, event: event) == nil
    }

    /// Trust check used before re-enabling a disabled tap. Injected in tests.
    var isTrusted: () -> Bool = PermissionsService.isAccessibilityTrusted

    /// Fired when the tap is torn down because permission was revoked.
    /// The owner should stop features cleanly (persisted toggles are kept).
    var onPermissionLost: (() -> Void)?

    init(
        tracker: FrontmostAppTracker,
        focusCache: FocusedElementCache,
        tapFactory: TapFactory? = nil
    ) {
        self.tracker = tracker
        self.focusCache = focusCache
        self.tapFactory = tapFactory ?? { mask, callback, userInfo in
            CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: userInfo
            )
        }
    }

    var consumerCount: Int {
        lock.synchronized { _consumers.count }
    }

    /// True while the tap is installed and listening.
    var isInstalled: Bool {
        lock.synchronized { tap != nil }
    }

    /// Test seam: the tap thread must stay alive while installed.
    var tapThreadIsRunning: Bool {
        lock.synchronized { thread?.isExecuting ?? false }
    }

    func addConsumer(_ consumer: any TapConsumer) {
        lock.synchronized {
            if !_consumers.contains(where: { $0 === consumer }) {
                _consumers.append(consumer)
                _consumers.sort { $0.tapPriority < $1.tapPriority }
            }
        }
        updateTapState()
    }

    func removeConsumer(_ consumer: any TapConsumer) {
        lock.synchronized {
            _consumers.removeAll { $0 === consumer }
        }
        updateTapState()
    }

    // MARK: - Tap lifecycle

    private static var eventsOfInterest: CGEventMask {
        let types: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .rightMouseDown]
        return types.reduce(0) { $0 | (CGEventMask(1) << CGEventMask($1.rawValue)) }
    }

    private func updateTapState() {
        let count = consumerCount
        if count > 0, !isInstalled {
            install()
        } else if count == 0, isInstalled {
            uninstall()
        }
    }

    private func install() {
        let consumerCount = consumerCount
        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = tapFactory(Self.eventsOfInterest, tapCallback, selfPointer) else {
            os_log("tap install failed: tapCreate returned nil (missing permission?)", log: tapLog, type: .error)
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        // The thread adds the source BEFORE running the loop: CFRunLoopRun
        // on an empty runloop returns immediately and the thread would die,
        // leaving an installed-but-deaf tap.
        let thread = TapThread { runLoop in
            CFRunLoopAddSource(runLoop, source, .commonModes)
        }
        thread.start()
        guard thread.waitForRunLoop(timeout: 1.0), thread.runLoop != nil else {
            os_log("tap install failed: tap thread did not start", log: tapLog, type: .error)
            CFMachPortInvalidate(tap)
            return
        }
        lock.synchronized {
            self.tap = tap
            self.runLoopSource = source
            self.thread = thread
        }
        focusCache.activate()
        os_log("tap installed (%d consumers)", log: tapLog, type: .info, consumerCount)
    }

    private func uninstall() {
        focusCache.deactivate()
        lock.synchronized {
            if let tap, let source = runLoopSource, let runLoop = thread?.runLoop {
                CFRunLoopRemoveSource(runLoop, source, .commonModes)
                CFMachPortInvalidate(tap)
                CFRunLoopStop(runLoop)
            }
            self.tap = nil
            runLoopSource = nil
            thread = nil
        }
        os_log("tap destroyed", log: tapLog, type: .info)
    }

    /// Handles a tap disabled by timeout or user input. Safe with no tap.
    /// Never fights a permission revocation: without trust the tap is torn
    /// down instead of re-enabled (re-enabling in a loop stalls event flow).
    func handleTapDisabled() {
        guard isTrusted() else {
            os_log("tap disabled and permission revoked; uninstalling", log: tapLog, type: .info)
            uninstall()
            onPermissionLost?()
            return
        }
        os_log("tap disabled by timeout/input; re-enabling", log: tapLog, type: .info)
        let currentTap: CFMachPort? = lock.synchronized { tap }
        if let currentTap {
            CGEvent.tapEnable(tap: currentTap, enable: true)
        }
    }

    // MARK: - Dispatch (runs on the tap thread)

    fileprivate func dispatch(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            handleTapDisabled()
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMark {
            return Unmanaged.passUnretained(event)
        }
        os_signpost(.event, log: tapLog, name: "tap", "type=%d", type.rawValue)
        let consumers: [any TapConsumer] = lock.synchronized { _consumers }
        for consumer in consumers {
            switch consumer.handle(event: event, type: type) {
            case .pass:
                continue
            case .consume:
                return nil
            case .replace(let events):
                for replacement in events {
                    replacement.post(tap: .cghidEventTap)
                }
                return nil
            }
        }
        return Unmanaged.passUnretained(event)
    }
}

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.dispatch(type: type, event: event)
}

/// Dedicated thread hosting the tap's runloop. The setup block runs on the
/// thread before the loop starts, so the tap source is always installed first.
private final class TapThread: Thread {
    private let setup: (CFRunLoop) -> Void
    private(set) var runLoop: CFRunLoop?
    private let ready = NSCondition()

    init(setup: @escaping (CFRunLoop) -> Void) {
        self.setup = setup
        super.init()
    }

    override func main() {
        let current = CFRunLoopGetCurrent()!
        setup(current)
        ready.lock()
        runLoop = current
        ready.signal()
        ready.unlock()
        CFRunLoopRun()
    }

    func waitForRunLoop(timeout: TimeInterval) -> Bool {
        ready.lock()
        defer { ready.unlock() }
        let deadline = Date().addingTimeInterval(timeout)
        while runLoop == nil, ready.wait(until: deadline) {}
        return runLoop != nil
    }
}

private extension NSLock {
    func synchronized<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}

#if DEBUG
// MARK: - Debug consumer

/// DEBUG-only: logs keycodes so tap wiring can be verified in Console.
/// Never compiled into Release (it would log keystrokes).
final class DebugTapConsumer: TapConsumer {
    let tapPriority = 1000

    func handle(event: CGEvent, type: CGEventType) -> TapResult {
        if type == .keyDown {
            os_log("keyDown keycode=%d", log: tapLog, type: .debug, event.getIntegerValueField(.keyboardEventKeycode))
        }
        return .pass
    }
}
#endif
