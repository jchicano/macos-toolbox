// SPDX-License-Identifier: MIT
// BreakScheduler: accumulation, idle pause, long-absence reset, snooze/skip.

import XCTest
@testable import ToolboxCore

final class BreakSchedulerTests: XCTestCase {
    private func makeScheduler(clock: ManualClock? = nil) -> (BreakScheduler, ManualClock) {
        let clock = clock ?? ManualClock()
        let scheduler = BreakScheduler(
            workSeconds: 60,
            breakSeconds: 300,
            idleResetSeconds: 300,
            clock: clock
        )
        scheduler.start()
        return (scheduler, clock)
    }

    private func sample(_ scheduler: BreakScheduler, clock: ManualClock, advance: TimeInterval, idle: TimeInterval) -> Bool {
        clock.advance(by: advance)
        return scheduler.sample(idleSeconds: idle)
    }

    func testBreakDueAfterWorkInterval() {
        let (scheduler, clock) = makeScheduler()
        XCTAssertFalse(sample(scheduler, clock: clock, advance: 30, idle: 0))
        XCTAssertTrue(sample(scheduler, clock: clock, advance: 30, idle: 0))
        XCTAssertTrue(scheduler.isDue)
    }

    func testDueLatchesUntilSnoozeOrSkip() {
        let (scheduler, clock) = makeScheduler()
        _ = sample(scheduler, clock: clock, advance: 60, idle: 0)
        XCTAssertFalse(sample(scheduler, clock: clock, advance: 30, idle: 0))
        scheduler.snooze(seconds: 300)
        XCTAssertFalse(scheduler.isDue)
        XCTAssertFalse(sample(scheduler, clock: clock, advance: 60, idle: 0))
        XCTAssertTrue(sample(scheduler, clock: clock, advance: 300, idle: 0))
    }

    func testSkipRestartsCounter() {
        let (scheduler, clock) = makeScheduler()
        _ = sample(scheduler, clock: clock, advance: 60, idle: 0)
        XCTAssertTrue(scheduler.isDue)
        scheduler.skip()
        XCTAssertFalse(scheduler.isDue)
        XCTAssertEqual(scheduler.accumulated, 0)
        XCTAssertFalse(sample(scheduler, clock: clock, advance: 30, idle: 0))
    }

    func testIdlePausesWithoutResetting() {
        // idleResetSeconds is 300 here; short idle pauses accumulation.
        let clock = ManualClock()
        let scheduler = BreakScheduler(workSeconds: 60, breakSeconds: 600, idleResetSeconds: 60, clock: clock)
        scheduler.start()
        _ = sample(scheduler, clock: clock, advance: 30, idle: 0)
        XCTAssertEqual(scheduler.accumulated, 30, accuracy: 0.001)
        // 70 s idle: paused, counter kept.
        _ = sample(scheduler, clock: clock, advance: 70, idle: 70)
        XCTAssertEqual(scheduler.accumulated, 30, accuracy: 0.001)
        XCTAssertFalse(scheduler.isDue)
        // Back to work: resumes from 30.
        XCTAssertTrue(sample(scheduler, clock: clock, advance: 30, idle: 0))
    }

    func testLongAbsenceResets() {
        // CA-1.3 style: absence beyond the break length resets the counter.
        let clock = ManualClock()
        let scheduler = BreakScheduler(workSeconds: 60, breakSeconds: 300, idleResetSeconds: 300, clock: clock)
        scheduler.start()
        _ = sample(scheduler, clock: clock, advance: 50, idle: 0)
        XCTAssertEqual(scheduler.accumulated, 50, accuracy: 0.001)
        _ = sample(scheduler, clock: clock, advance: 360, idle: 360)
        XCTAssertEqual(scheduler.accumulated, 0, accuracy: 0.001)
        XCTAssertFalse(scheduler.isDue)
    }

    func testStartBreakResets() {
        let (scheduler, clock) = makeScheduler()
        _ = sample(scheduler, clock: clock, advance: 60, idle: 0)
        scheduler.startBreak()
        XCTAssertFalse(scheduler.isDue)
        XCTAssertEqual(scheduler.accumulated, 0)
    }
}
