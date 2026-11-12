// SPDX-License-Identifier: MIT
// Registry behavior: persistence, gating, idempotency, restore, stopAll.

import ApplicationServices
import XCTest
import ToolboxCore
@testable import Toolbox

/// Controllable feature for registry tests.
final class FakeFeature: Feature {
    static var descriptor: FeatureDescriptor { FeatureCatalog.all[0] }

    let descriptor: FeatureDescriptor
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(descriptor: FeatureDescriptor) {
        self.descriptor = descriptor
    }

    func start() throws {
        startCount += 1
        isRunning = true
    }

    func stop() {
        stopCount += 1
        isRunning = false
    }
}

final class FeatureRegistryTests: XCTestCase {
    private func makeStore() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: #function + UUID().uuidString)!)
    }

    private func makeRegistry(granted: Bool = true, store: SettingsStore? = nil) -> (FeatureRegistry, SettingsStore, [FakeFeature]) {
        let store = store ?? makeStore()
        let fakes = FeatureCatalog.all.map { FakeFeature(descriptor: $0) }
        let registry = FeatureRegistry(
            features: fakes,
            store: store,
            isAccessibilityGranted: { granted }
        )
        return (registry, store, fakes)
    }

    func testEnableStartsFeatureAndPersists() {
        let (registry, store, fakes) = makeRegistry()
        XCTAssertEqual(registry.setEnabled(true, for: .breaks), .enabled)
        XCTAssertTrue(fakes[0].isRunning)
        XCTAssertEqual(fakes[0].startCount, 1)
        XCTAssertTrue(store.settings.enabled.contains(.breaks))
    }

    func testEnableIsIdempotent() {
        let (registry, _, fakes) = makeRegistry()
        _ = registry.setEnabled(true, for: .keepAwake)
        _ = registry.setEnabled(true, for: .keepAwake)
        XCTAssertEqual(fakes[1].startCount, 1)
        XCTAssertTrue(fakes[1].isRunning)
    }

    func testDisableStopsAndRemoves() {
        let (registry, store, fakes) = makeRegistry()
        _ = registry.setEnabled(true, for: .breaks)
        XCTAssertEqual(registry.setEnabled(false, for: .breaks), .disabled)
        XCTAssertFalse(fakes[0].isRunning)
        XCTAssertFalse(store.settings.enabled.contains(.breaks))
    }

    func testGatingBlocksWithoutPermission() {
        let (registry, store, fakes) = makeRegistry(granted: false)
        XCTAssertEqual(registry.setEnabled(true, for: .autoClose), .needsPermission(.accessibility))
        XCTAssertFalse(fakes[2].isRunning)
        XCTAssertEqual(fakes[2].startCount, 0)
        XCTAssertFalse(store.settings.enabled.contains(.autoClose))
    }

    func testGatingPassesPermissionlessFeatures() {
        let (registry, _, fakes) = makeRegistry(granted: false)
        XCTAssertEqual(registry.setEnabled(true, for: .breaks), .enabled)
        XCTAssertTrue(fakes[0].isRunning)
    }

    func testGatingAllowsWhenGranted() {
        let (registry, _, fakes) = makeRegistry(granted: true)
        XCTAssertEqual(registry.setEnabled(true, for: .autoClose), .enabled)
        XCTAssertTrue(fakes[2].isRunning)
    }

    func testRestoreOnLaunchStartsPersistedPermissionless() {
        let store = makeStore()
        store.update { $0.enabled = [.breaks, .keepAwake] }
        let (registry, _, fakes) = makeRegistry(granted: false, store: store)
        registry.restoreOnLaunch()
        XCTAssertTrue(fakes[0].isRunning)
        XCTAssertTrue(fakes[1].isRunning)
    }

    func testRestoreOnLaunchSkipsRevokedPermission() {
        let store = makeStore()
        store.update { $0.enabled = [.autoClose] }
        let (registry, _, fakes) = makeRegistry(granted: false, store: store)
        registry.restoreOnLaunch()
        XCTAssertFalse(fakes[2].isRunning)
        // The choice stays persisted so the menu can warn (F3).
        XCTAssertTrue(store.settings.enabled.contains(.autoClose))
    }

    func testStopAll() {
        let (registry, _, fakes) = makeRegistry()
        _ = registry.setEnabled(true, for: .breaks)
        _ = registry.setEnabled(true, for: .keepAwake)
        registry.stopAll()
        XCTAssertFalse(fakes[0].isRunning)
        XCTAssertFalse(fakes[1].isRunning)
    }

    func testStartPersistedFeaturesResumesAfterGrant() {
        let store = makeStore()
        store.update { $0.enabled = [.autoClose, .snippets] }
        var granted = false
        let fakes = FeatureCatalog.all.map { FakeFeature(descriptor: $0) }
        let registry = FeatureRegistry(
            features: fakes,
            store: store,
            isAccessibilityGranted: { granted }
        )

        registry.restoreOnLaunch()
        XCTAssertFalse(fakes[2].isRunning)
        XCTAssertFalse(fakes[3].isRunning)

        // The user grants Accessibility in System Settings while the app runs.
        granted = true
        registry.startPersistedFeatures()
        XCTAssertTrue(fakes[2].isRunning)
        XCTAssertTrue(fakes[3].isRunning)
    }

    func testStartPersistedFeaturesSkipsRunningFeatures() {
        let store = makeStore()
        store.update { $0.enabled = [.breaks] }
        let (registry, _, fakes) = makeRegistry(store: store)
        registry.startPersistedFeatures()
        registry.startPersistedFeatures()
        XCTAssertEqual(fakes[0].startCount, 1)
    }

    func testRestartRestartsEnabledFeature() {
        let (registry, _, fakes) = makeRegistry()
        _ = registry.setEnabled(true, for: .breaks)
        let starts = fakes[0].startCount
        registry.restart(.breaks)
        XCTAssertTrue(fakes[0].isRunning)
        XCTAssertEqual(fakes[0].startCount, starts + 1)
    }

    func testRestartSkipsDisabledFeature() {
        let (registry, _, fakes) = makeRegistry()
        registry.restart(.breaks)
        XCTAssertFalse(fakes[0].isRunning)
        XCTAssertEqual(fakes[0].startCount, 0)
    }

    func testUnknownFeatureIsDisabled() {
        // Registry built with a subset: other ids are unknown.
        let store = makeStore()
        let registry = FeatureRegistry(features: [], store: store)
        XCTAssertEqual(registry.setEnabled(true, for: .breaks), .disabled)
    }
}
