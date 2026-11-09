// SPDX-License-Identifier: MIT
// Output formats for the color picker. Value formatting lands in F2.

public enum ColorFormat: String, Codable, CaseIterable {
    case hex
    case rgb
    case hsl
    case swiftUI
    case nsColor
}
