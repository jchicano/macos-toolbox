// SPDX-License-Identifier: MIT
// Feature model: permissions, kinds, descriptors and the Feature contract.

import AppKit
import ToolboxCore

/// macOS permissions a feature may require before it can start.
public enum Permission: Hashable {
    case accessibility
    case notifications
    case automation
}

/// Toggle features show a checkmark; actions run once per click.
public enum FeatureKind {
    case toggle
    case action
}

/// Static declaration of a feature. The menu is generated from the catalog,
/// so adding a feature only needs a descriptor plus a class.
public struct FeatureDescriptor {
    public let id: FeatureID
    /// Localizable.strings key for the menu title (English by default).
    public let titleKey: String
    public let kind: FeatureKind
    public let requiredPermissions: Set<Permission>
    public let menuOrder: Int

    public init(id: FeatureID, titleKey: String, kind: FeatureKind, requiredPermissions: Set<Permission>, menuOrder: Int) {
        self.id = id
        self.titleKey = titleKey
        self.kind = kind
        self.requiredPermissions = requiredPermissions
        self.menuOrder = menuOrder
    }
}

public enum FeatureError: Error, Equatable {
    case permissionMissing(Permission)
}

/// A unit of functionality owned by the registry.
/// start/stop must be idempotent; stop must release every live resource.
public protocol Feature: AnyObject {
    static var descriptor: FeatureDescriptor { get }
    var descriptor: FeatureDescriptor { get }
    var isRunning: Bool { get }
    /// Overrides the menu title (e.g. Auto-close lists active pairs). Nil = catalog title.
    var menuTitle: String? { get }
    func start() throws
    func stop()
    func makeSubmenu() -> NSMenu?
}

public extension Feature {
    var descriptor: FeatureDescriptor { Self.descriptor }
    var menuTitle: String? { nil }
    func makeSubmenu() -> NSMenu? { nil }
}
