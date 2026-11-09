// SPDX-License-Identifier: MIT
// SettingsStore: load, save, corrupt-data backup.

import XCTest
import ToolboxCore
@testable import Toolbox

final class SettingsStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: #function + UUID().uuidString)!
    }

    func testDefaultsWhenEmpty() {
        let store = SettingsStore(defaults: makeDefaults())
        XCTAssertEqual(store.settings, Settings())
    }

    func testUpdatePersistsAndReloads() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        store.update {
            $0.enabled = [.breaks]
            $0.breaks.workMinutes = 25
        }
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertTrue(reloaded.settings.enabled.contains(.breaks))
        XCTAssertEqual(reloaded.settings.breaks.workMinutes, 25)
    }

    func testCorruptDataBacksUpAndResets() throws {
        let defaults = makeDefaults()
        let garbage = Data("not-json".utf8)
        defaults.set(garbage, forKey: SettingsStore.key)
        let store = SettingsStore(defaults: defaults)
        XCTAssertEqual(store.settings, Settings())
        XCTAssertEqual(defaults.data(forKey: SettingsStore.backupKey), garbage)
        XCTAssertNil(defaults.data(forKey: SettingsStore.key))
    }
}
