// SPDX-License-Identifier: MIT
// Settings round-trip, defaults and migration.

import XCTest
@testable import ToolboxCore

final class SettingsTests: XCTestCase {
    func testDefaultsMatchPlan() {
        let settings = Settings()
        XCTAssertEqual(settings.schemaVersion, 1)
        XCTAssertTrue(settings.enabled.isEmpty)
        XCTAssertEqual(settings.breaks.workMinutes, 50)
        XCTAssertEqual(settings.breaks.breakMinutes, 5)
        XCTAssertFalse(settings.breaks.overlay)
        XCTAssertTrue(settings.autoClose.tabOut)
        XCTAssertTrue(settings.autoClose.overtype)
        XCTAssertTrue(settings.autoClose.deletePair)
        XCTAssertTrue(settings.autoClose.smartQuotes)
        XCTAssertFalse(settings.autoClose.requireEditableFocus)
        XCTAssertEqual(settings.autoClose.pairs.count, 12)
        XCTAssertEqual(settings.colorPicker.format, .hex)
        XCTAssertTrue(settings.colorPicker.uppercase)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testRoundTrip() throws {
        var settings = Settings()
        settings.enabled = [.breaks, .keepAwake, .autoClose]
        settings.breaks.workMinutes = 25
        settings.keepAwake.defaultDuration = 3600
        settings.colorPicker.recents = ["#1E90FF"]
        settings.snippets.dateFormat = "dd/MM/yyyy"
        let data = try JSONEncoder().encode(settings)
        var decoded = try JSONDecoder().decode(Settings.self, from: data)
        decoded.migrate()
        XCTAssertEqual(decoded, settings)
    }

    func testRejectsUnknownSchemaWithoutMigration() throws {
        var settings = Settings()
        settings.schemaVersion = 999
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, 999)
    }
}
