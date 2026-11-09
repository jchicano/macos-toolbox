// SPDX-License-Identifier: MIT
// Typed UserDefaults persistence for Settings (JSON, versioned, with backup).

import Combine
import Foundation
import ToolboxCore

/// Loads, saves and publishes Settings. Corrupt data is backed up under
/// `backupKey` and replaced with defaults instead of crashing.
final class SettingsStore: ObservableObject {
    static let key = "toolbox.settings"
    static let backupKey = "toolbox.settings.bak"

    @Published private(set) var settings: Settings

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? decoder.decode(Settings.self, from: data)
        {
            var migrated = decoded
            migrated.migrate()
            settings = migrated
        } else {
            if let data = defaults.data(forKey: Self.key) {
                defaults.set(data, forKey: Self.backupKey)
                defaults.removeObject(forKey: Self.key)
            }
            settings = Settings()
        }
    }

    /// Mutates settings, persists and publishes in one step.
    func update(_ mutate: (inout Settings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
        save()
    }

    private func save() {
        if let data = try? encoder.encode(settings) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
