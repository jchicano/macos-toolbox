// SPDX-License-Identifier: MIT
// F1 placeholder features. Each real feature (F2+) replaces its stub.

import AppKit

/// Minimal toggle/action used until the real implementation lands.
/// State-only: start/stop flip isRunning, no system resources involved.
final class StubFeature: Feature {
    static var descriptor: FeatureDescriptor {
        // Placeholder; instances always carry their own descriptor.
        FeatureCatalog.all[0]
    }

    let descriptor: FeatureDescriptor
    private(set) var isRunning = false

    init(descriptor: FeatureDescriptor) {
        self.descriptor = descriptor
    }

    func start() throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }

    /// One stub per catalog entry, in menu order.
    static func makeDefaults() -> [StubFeature] {
        FeatureCatalog.all.map(StubFeature.init(descriptor:))
    }
}
