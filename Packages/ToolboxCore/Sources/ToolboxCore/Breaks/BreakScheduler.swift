// SPDX-License-Identifier: MIT
// Pure work/break timing. The feature samples it periodically with the real
// idle time; tests drive it with a ManualClock.

import Foundation

/// Accumulates active work time, pausing while the user is idle and resetting
/// after long absences. All time flows through the injected clock.
public final class BreakScheduler {
    public var workSeconds: TimeInterval
    public var breakSeconds: TimeInterval
    public var idleResetSeconds: TimeInterval

    private let clock: Clock
    private var activeSeconds: TimeInterval = 0
    private var lastSample: Date?
    private var dueLatched = false
    private var snoozeUntil: Date?

    public init(
        workSeconds: TimeInterval,
        breakSeconds: TimeInterval,
        idleResetSeconds: TimeInterval,
        clock: Clock = SystemClock()
    ) {
        self.workSeconds = workSeconds
        self.breakSeconds = breakSeconds
        self.idleResetSeconds = idleResetSeconds
        self.clock = clock
    }

    public var accumulated: TimeInterval { activeSeconds }

    public var remaining: TimeInterval {
        max(0, workSeconds - activeSeconds)
    }

    public var isDue: Bool { dueLatched }

    public func start() {
        activeSeconds = 0
        lastSample = clock.now
        dueLatched = false
        snoozeUntil = nil
    }

    /// Feed one idle reading. Returns true on the transition to due.
    @discardableResult
    public func sample(idleSeconds: TimeInterval) -> Bool {
        let now = clock.now
        defer { lastSample = now }
        guard !dueLatched else { return false }
        if let snoozeUntil, now < snoozeUntil {
            lastSample = now
            return false
        }
        snoozeUntil = nil
        if idleSeconds >= breakSeconds {
            // Long absence: start fresh.
            activeSeconds = 0
            lastSample = now
            return false
        }
        if idleSeconds >= idleResetSeconds {
            // Paused: don't accumulate, don't reset.
            return false
        }
        if let lastSample {
            activeSeconds += max(0, now.timeIntervalSince(lastSample))
        }
        if activeSeconds >= workSeconds {
            dueLatched = true
            return true
        }
        return false
    }

    /// Postpone the break; the work counter is kept.
    public func snooze(seconds: TimeInterval) {
        dueLatched = false
        snoozeUntil = clock.now.addingTimeInterval(seconds)
    }

    /// Dismiss the break and restart the work counter.
    public func skip() {
        start()
    }

    /// The user started the break now; restart the work counter.
    public func startBreak() {
        start()
    }
}
