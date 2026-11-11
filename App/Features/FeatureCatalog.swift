// SPDX-License-Identifier: MIT
// Single catalog of features. Menu order and gating derive from here.

import Foundation
import ToolboxCore

/// The one place that lists every built-in feature, in menu order (§0).
enum FeatureCatalog {
    static let all: [FeatureDescriptor] = [
        FeatureDescriptor(
            id: .breaks,
            titleKey: "Breaks",
            kind: .toggle,
            requiredPermissions: [],
            menuOrder: 0
        ),
        FeatureDescriptor(
            id: .keepAwake,
            titleKey: "Keep Awake",
            kind: .toggle,
            requiredPermissions: [],
            menuOrder: 1
        ),
        FeatureDescriptor(
            id: .autoClose,
            titleKey: "Auto-close",
            kind: .toggle,
            requiredPermissions: [.accessibility],
            menuOrder: 2
        ),
        FeatureDescriptor(
            id: .snippets,
            titleKey: "Snippets",
            kind: .toggle,
            requiredPermissions: [.accessibility],
            menuOrder: 3
        ),
        FeatureDescriptor(
            id: .colorPicker,
            titleKey: "Color Picker",
            kind: .action,
            requiredPermissions: [],
            menuOrder: 4
        ),
    ]

    static func descriptor(for id: FeatureID) -> FeatureDescriptor? {
        all.first { $0.id == id }
    }
}
