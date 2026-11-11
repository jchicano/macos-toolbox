// SPDX-License-Identifier: MIT
// Stable feature identifiers shared by Settings persistence and the registry.

/// Identifiers of the built-in features, in menu order.
public enum FeatureID: String, Codable, Hashable, CaseIterable, Sendable {
    case breaks
    case keepAwake
    case autoClose
    case snippets
    case colorPicker

    /// Removed in 0.2.0 at user request. Kept so old persisted `enabled`
    /// sets still decode (the id is inert: not in the catalog, never started).
    case scrollVim
}
