// SPDX-License-Identifier: MIT
// ColorFormatter: hex, rgb(), hsl(), SwiftUI and NSColor outputs (CA-5.4).

import XCTest
@testable import ToolboxCore

final class ColorFormatterTests: XCTestCase {
    // Dodger blue: (30, 144, 255).
    private let blue = SRGBColor(red: 30.0 / 255, green: 144.0 / 255, blue: 1.0)

    func testHexUppercaseDefault() {
        XCTAssertEqual(blue.formatted(as: .hex), "#1E90FF")
    }

    func testHexLowercase() {
        XCTAssertEqual(blue.formatted(as: .hex, uppercaseHex: false), "#1e90ff")
    }

    func testRGB() {
        XCTAssertEqual(blue.formatted(as: .rgb), "rgb(30, 144, 255)")
    }

    func testHSL() {
        XCTAssertEqual(blue.formatted(as: .hsl), "hsl(210, 100%, 56%)")
    }

    func testAchromaticHSL() {
        let white = SRGBColor(red: 1, green: 1, blue: 1)
        XCTAssertEqual(white.formatted(as: .hex), "#FFFFFF")
        XCTAssertEqual(white.formatted(as: .hsl), "hsl(0, 0%, 100%)")
    }

    func testSwiftUI() {
        XCTAssertEqual(
            blue.formatted(as: .swiftUI),
            "Color(red: 0.118, green: 0.565, blue: 1.000)"
        )
    }

    func testNSColor() {
        XCTAssertEqual(
            blue.formatted(as: .nsColor),
            "NSColor(srgbRed: 0.118, green: 0.565, blue: 1.000, alpha: 1.0)"
        )
    }
}
