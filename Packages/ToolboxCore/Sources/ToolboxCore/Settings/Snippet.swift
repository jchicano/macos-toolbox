// SPDX-License-Identifier: MIT
// Snippet model. Storage (JSON file) and engine land in F6.

import Foundation

public struct Snippet: Codable, Equatable, Identifiable {
    public var id: UUID
    public var trigger: String
    public var title: String
    public var body: String
    public var enabled: Bool

    public init(id: UUID = UUID(), trigger: String, title: String, body: String, enabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.title = title
        self.body = body
        self.enabled = enabled
    }
}
