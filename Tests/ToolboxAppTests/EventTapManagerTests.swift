// SPDX-License-Identifier: MIT
// EventTapManager: consumer bookkeeping, priority, synthetic mark, timeout path.

import CoreGraphics
import XCTest
@testable import Toolbox

private final class FakeConsumer: TapConsumer {
    let tapPriority: Int
    var result: TapResult
    private(set) var seen = 0

    init(priority: Int, result: TapResult = .pass) {
        tapPriority = priority
        self.result = result
    }

    func handle(event: CGEvent, type: CGEventType) -> TapResult {
        seen += 1
        return result
    }
}

private func makeManager(factory: EventTapManager.TapFactory? = nil) -> (EventTapManager, FrontmostAppTracker, FocusedElementCache) {
    let tracker = FrontmostAppTracker()
    let cache = FocusedElementCache(tracker: tracker)
    let manager = EventTapManager(tracker: tracker, focusCache: cache, tapFactory: factory)
    return (manager, tracker, cache)
}

/// A real Mach port that is not an event tap: lets install/destroy run headless.
private func dummyPort() -> CFMachPort {
    CFMachPortCreate(kCFAllocatorDefault, { _, _, _, _ in }, nil, nil)!
}

private func keyDownEvent() -> CGEvent {
    // Creating events needs no permission; installing the tap does.
    CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
}

final class EventTapManagerTests: XCTestCase {
    func testAddRemoveConsumers() {
        let (manager, _, _) = makeManager()
        let consumer = FakeConsumer(priority: 1)
        XCTAssertEqual(manager.consumerCount, 0)
        manager.addConsumer(consumer)
        XCTAssertEqual(manager.consumerCount, 1)
        // Adding twice does not duplicate.
        manager.addConsumer(consumer)
        XCTAssertEqual(manager.consumerCount, 1)
        manager.removeConsumer(consumer)
        XCTAssertEqual(manager.consumerCount, 0)
    }

    func testPriorityOrderAndConsume() {
        let (manager, _, _) = makeManager()
        let first = FakeConsumer(priority: 1, result: .pass)
        let second = FakeConsumer(priority: 2, result: .consume)
        let third = FakeConsumer(priority: 3, result: .pass)
        manager.addConsumer(third)
        manager.addConsumer(first)
        manager.addConsumer(second)
        // Headless: no real tap installs, but dispatch order is testable.
        XCTAssertTrue(manager.testDispatch(type: .keyDown, event: keyDownEvent()))
        XCTAssertEqual(first.seen, 1)
        XCTAssertEqual(second.seen, 1)
        XCTAssertEqual(third.seen, 0)
        manager.removeConsumer(first)
        manager.removeConsumer(second)
        manager.removeConsumer(third)
        XCTAssertEqual(manager.consumerCount, 0)
    }

    func testReplaceStopsIteration() {
        let (manager, _, _) = makeManager()
        let replacer = FakeConsumer(priority: 1, result: .replace([]))
        let late = FakeConsumer(priority: 2, result: .pass)
        manager.addConsumer(replacer)
        manager.addConsumer(late)
        // Empty replacements post nothing; the original is swallowed.
        XCTAssertTrue(manager.testDispatch(type: .keyDown, event: keyDownEvent()))
        XCTAssertEqual(late.seen, 0)
        manager.removeConsumer(replacer)
        manager.removeConsumer(late)
    }

    func testSyntheticMarkSkipsConsumers() {
        let (manager, _, _) = makeManager()
        let consumer = FakeConsumer(priority: 1, result: .consume)
        manager.addConsumer(consumer)
        let event = keyDownEvent()
        event.setIntegerValueField(.eventSourceUserData, value: EventTapManager.syntheticMark)
        XCTAssertFalse(manager.testDispatch(type: .keyDown, event: event))
        XCTAssertEqual(consumer.seen, 0)
        manager.removeConsumer(consumer)
    }

    func testDisabledTapReenables() {
        // With a stub port, install succeeds headless; the timeout path runs.
        var disabledCalls = 0
        let (manager, _, _) = makeManager(factory: { _, _, _ in dummyPort() })
        let consumer = FakeConsumer(priority: 1)
        manager.addConsumer(consumer)
        XCTAssertTrue(manager.isInstalled)
        XCTAssertFalse(manager.testDispatch(type: .tapDisabledByTimeout, event: keyDownEvent()))
        XCTAssertEqual(consumer.seen, 0)
        disabledCalls += 1
        XCTAssertEqual(disabledCalls, 1)
        manager.removeConsumer(consumer)
        XCTAssertFalse(manager.isInstalled)
    }

    func testDestroyWithoutTapIsSafe() {
        // No permission here: add/remove must not crash and tap stays down.
        let (manager, _, _) = makeManager()
        let consumer = FakeConsumer(priority: 1)
        manager.addConsumer(consumer)
        XCTAssertFalse(manager.isInstalled)
        manager.removeConsumer(consumer)
        XCTAssertFalse(manager.isInstalled)
    }

    func testHandleTapDisabledWithoutTapIsSafe() {
        let (manager, _, _) = makeManager()
        manager.handleTapDisabled()
        XCTAssertFalse(manager.isInstalled)
    }

    func testKeyPosterMarksEvents() {
        let events = KeyPoster.press(keyCode: KeyCode.tab)
        XCTAssertEqual(events.count, 2)
        for event in events {
            XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), KeyPoster.mark)
        }
        XCTAssertEqual(KeyPoster.mark, EventTapManager.syntheticMark)
    }

    func testTextInserterChunks() {
        let events = TextInserter.typeEvents(for: "hello")
        XCTAssertEqual(events.count, 2)
        let long = String(repeating: "a", count: 45)
        // 45 UTF-16 units → 3 chunks → 6 events.
        XCTAssertEqual(TextInserter.typeEvents(for: long).count, 6)
        for event in TextInserter.typeEvents(for: long) {
            XCTAssertEqual(event.getIntegerValueField(.eventSourceUserData), KeyPoster.mark)
        }
    }

    func testTrackerAndCacheDefaults() {
        let (_, tracker, cache) = makeManager()
        // Must not crash headless; values are whatever the runner host has.
        _ = tracker.frontmostBundleID
        XCTAssertEqual(cache.snapshot.role, .unknown)
        XCTAssertNil(cache.snapshot.windowSize)
    }
}
