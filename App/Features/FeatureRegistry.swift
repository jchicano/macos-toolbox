// SPDX-License-Identifier: MIT
// Registry: owns feature instances, gates on permissions, persists state.

import ApplicationServices
import Combine
import Foundation
import ToolboxCore

/// Outcome of a toggle request from the menu.
enum ToggleResult: Equatable {
    case enabled
    case disabled
    case needsPermission(Permission)
}

/// Owns every feature: permission gating, enabled persistence, lifecycle.
/// F1 uses stub features; F2+ replaces them one by one with real ones.
final class FeatureRegistry: ObservableObject {
    /// Bumped on every state change so the menu can rebuild.
    @Published private(set) var generation = 0

    private let store: SettingsStore
    private let isAccessibilityGranted: () -> Bool
    private var features: [FeatureID: any Feature] = [:]

    init(
        features: [any Feature],
        store: SettingsStore,
        isAccessibilityGranted: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.store = store
        self.isAccessibilityGranted = isAccessibilityGranted
        for feature in features {
            self.features[feature.descriptor.id] = feature
        }
    }

    func feature(for id: FeatureID) -> (any Feature)? {
        features[id]
    }

    func isEnabled(_ id: FeatureID) -> Bool {
        store.settings.enabled.contains(id)
    }

    func isRunning(_ id: FeatureID) -> Bool {
        features[id]?.isRunning ?? false
    }

    func descriptor(for id: FeatureID) -> FeatureDescriptor? {
        FeatureCatalog.descriptor(for: id)
    }

    private func missingPermission(for descriptor: FeatureDescriptor) -> Permission? {
        if descriptor.requiredPermissions.contains(.accessibility), !isAccessibilityGranted() {
            return .accessibility
        }
        return nil
    }

    /// Enables or disables a feature. Never marks the check without starting.
    @discardableResult
    func setEnabled(_ enabled: Bool, for id: FeatureID) -> ToggleResult {
        guard let descriptor = FeatureCatalog.descriptor(for: id),
              let feature = features[id]
        else { return .disabled }

        if !enabled {
            if !store.settings.enabled.contains(id) {
                // Already disabled: still ensure stopped (idempotent).
                feature.stop()
                return .disabled
            }
            feature.stop()
            store.update { $0.enabled.remove(id) }
            generation += 1
            return .disabled
        }
        if store.settings.enabled.contains(id), feature.isRunning {
            return .enabled
        }
        if let missing = missingPermission(for: descriptor) {
            return .needsPermission(missing)
        }
        do {
            try feature.start()
        } catch {
            return .disabled
        }
        store.update { $0.enabled.insert(id) }
        generation += 1
        return .enabled
    }

    /// Runs an action feature once (no persisted state).
    func run(_ id: FeatureID) {
        guard let feature = features[id] else { return }
        try? feature.start()
    }

    /// Starts every persisted feature whose permissions are granted.
    /// Permission-gated features stay persisted but stopped until granted (F3 warns in the menu).
    func restoreOnLaunch() {
        for descriptor in FeatureCatalog.all where store.settings.enabled.contains(descriptor.id) {
            guard missingPermission(for: descriptor) == nil,
                  let feature = features[descriptor.id]
            else { continue }
            try? feature.start()
        }
        generation += 1
    }

    /// Stops everything. Called from applicationWillTerminate.
    func stopAll() {
        for feature in features.values {
            feature.stop()
        }
        generation += 1
    }
}
