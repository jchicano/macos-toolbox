// SPDX-License-Identifier: MIT
// Pixel scroll posts for Vim-style half-page scrolling.

import CoreGraphics
import Foundation

/// Posts marked synthetic scroll events, optionally smoothed.
enum ScrollPoster {
    /// Posts a pixel scroll at a virtual location. Positive delta scrolls up.
    static func scroll(pixels: Int, smooth: Bool, at location: CGPoint?) {
        guard pixels != 0 else { return }
        if smooth {
            // Split into 6 chunks ~8 ms apart; first posts synchronously.
            let chunk = pixels / 6
            let remainder = pixels - chunk * 5
            post(pixels: chunk, at: location)
            for i in 1 ..< 6 {
                let amount = (i == 5) ? remainder : chunk
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(i) * 0.008) {
                    post(pixels: amount, at: location)
                }
            }
        } else {
            post(pixels: pixels, at: location)
        }
    }

    private static func post(pixels: Int, at location: CGPoint?) {
        guard pixels != 0,
              let event = CGEvent(
                  scrollWheelEvent2Source: nil,
                  units: .pixel,
                  wheelCount: 1,
                  wheel1: Int32(pixels),
                  wheel2: 0,
                  wheel3: 0
              )
        else { return }
        if let location {
            event.location = location
        }
        KeyPoster.mark(event)
        event.post(tap: .cghidEventTap)
    }
}
