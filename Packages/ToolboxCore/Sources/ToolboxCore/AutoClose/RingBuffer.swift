// SPDX-License-Identifier: MIT
// Fixed-capacity ring buffer for recent-keystroke context (smart quotes).

public struct RingBuffer<Element> {
    private var storage: [Element] = []
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
    public var last: Element? { storage.last }

    public mutating func push(_ element: Element) {
        storage.append(element)
        if storage.count > capacity {
            storage.removeFirst(storage.count - capacity)
        }
    }

    public mutating func clear() {
        storage.removeAll(keepingCapacity: true)
    }
}
