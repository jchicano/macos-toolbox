// SPDX-License-Identifier: MIT
// Injectable clock for schedulers. Production uses SystemClock; tests use ManualClock.

import Foundation

public protocol Clock {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// Controllable clock for unit tests.
public final class ManualClock: Clock {
    public var now: Date

    public init(startingAt date: Date = Date()) {
        now = date
    }

    public func advance(by interval: TimeInterval) {
        now = now.addingTimeInterval(interval)
    }
}
