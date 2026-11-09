// SPDX-License-Identifier: MIT
// sRGB triple formatting for the color picker. AppKit conversion lives in the app.

import Foundation

/// Plain sRGB color with 0...1 components.
public struct SRGBColor: Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    private var bytes: (Int, Int, Int) {
        (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    public func formatted(as format: ColorFormat, uppercaseHex: Bool = true) -> String {
        switch format {
        case .hex:
            let hex = String(format: "#%02X%02X%02X", bytes.0, bytes.1, bytes.2)
            return uppercaseHex ? hex : hex.lowercased()
        case .rgb:
            return "rgb(\(bytes.0), \(bytes.1), \(bytes.2))"
        case .hsl:
            let (h, s, l) = hsl
            return "hsl(\(h), \(s)%, \(l)%)"
        case .swiftUI:
            return String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", red, green, blue)
        case .nsColor:
            return String(format: "NSColor(srgbRed: %.3f, green: %.3f, blue: %.3f, alpha: 1.0)", red, green, blue)
        }
    }

    private var hsl: (Int, Int, Int) {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        let lightness = (maxC + minC) / 2
        guard delta > 0 else { return (0, 0, Int((lightness * 100).rounded())) }
        let saturation = delta / (1 - abs(2 * lightness - 1))
        let hue: Double
        if maxC == red {
            hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
        } else if maxC == green {
            hue = 60 * ((blue - red) / delta + 2)
        } else {
            hue = 60 * ((red - green) / delta + 4)
        }
        let degrees = Int((hue < 0 ? hue + 360 : hue).rounded())
        return (degrees, Int((saturation * 100).rounded()), Int((lightness * 100).rounded()))
    }
}
