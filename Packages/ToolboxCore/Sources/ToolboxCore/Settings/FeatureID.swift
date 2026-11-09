// SPDX-License-Identifier: MIT
// Stable feature identifiers shared by Settings persistence and the registry.

/// Identifiers of the built-in features, in menu order.
public enum FeatureID: String, Codable, Hashable, CaseIterable, Sendable {
    case breaks
    case keepAwake
    case scrollVim
    case autoClose
    case snippets
    case colorPicker
}
