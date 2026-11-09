// SPDX-License-Identifier: MIT
// Features that push state changes (timers, notifications) so the menu rebuilds.

import Foundation

/// A feature that reports asynchronous state changes via onChange.
/// The registry wires onChange to bump its generation (menu rebuild).
protocol StatefulFeature: Feature, AnyObject {
    var onChange: (() -> Void)? { get set }
}
