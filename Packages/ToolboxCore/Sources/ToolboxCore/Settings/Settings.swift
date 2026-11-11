// SPDX-License-Identifier: MIT
// Versioned app settings persisted as JSON in UserDefaults.
// Data edited by the user (snippets) lives in a separate JSON file (F6).

import Foundation

public struct Settings: Codable, Equatable {
    public var schemaVersion = 1
    public var enabled: Set<FeatureID> = []

    public var breaks = BreaksSettings()
    public var keepAwake = KeepAwakeSettings()
    public var autoClose = AutoCloseSettings()
    public var colorPicker = ColorPickerSettings()
    public var snippets = SnippetsSettings()
    public var launchAtLogin = false

    public init() {}

    // MARK: - Migration

    /// Migrates decoded settings to the current schema. Unknown future
    /// versions are kept as-is here; SettingsStore resets them to defaults.
    public mutating func migrate() {
        if schemaVersion < 1 { schemaVersion = 1 }
    }

    // MARK: - Nested settings

    public struct BreaksSettings: Codable, Equatable {
        public var workMinutes = 50
        public var breakMinutes = 5
        public var idleResetMinutes = 5
        public var overlay = false
        public var sound = true
        public init() {}
    }

    public struct KeepAwakeSettings: Codable, Equatable {
        public var allowDisplaySleep = false
        /// Nil means indefinite.
        public var defaultDuration: TimeInterval?
        public init() {}
    }

    public struct AutoCloseSettings: Codable, Equatable {
        public var pairs: [Pair] = Pair.defaults
        public var tabOut = true
        public var overtype = true
        public var deletePair = true
        /// Skip pairing for symmetric quotes after alphanumerics (don't, l'amic).
        public var smartQuotes = true
        public var requireEditableFocus = false
        public var filter = AppFilter(mode: .denylist, bundleIDs: AppFilter.defaultAutoCloseDeny)
        public init() {}
    }

    public struct ColorPickerSettings: Codable, Equatable {
        public var format: ColorFormat = .hex
        public var uppercase = true
        /// Most recent first, sRGB hex, max 10.
        public var recents: [String] = []
        public init() {}
    }

    public struct SnippetsSettings: Codable, Equatable {
        public var expandOnDelimiter = true
        public var expandImmediately = false
        public var dateFormat = "yyyy-MM-dd"
        public var timeFormat = "HH:mm"
        public var filter = AppFilter(mode: .denylist, bundleIDs: [])
        public init() {}
    }
}
