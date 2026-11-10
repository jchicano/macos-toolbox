// SPDX-License-Identifier: MIT
// Snippets JSON file in Application Support (versioned, import/export).

import Foundation

/// File envelope for snippets.json.
public struct SnippetFile: Codable, Equatable {
    public var version: Int
    public var snippets: [Snippet]

    public init(version: Int = 1, snippets: [Snippet] = []) {
        self.version = version
        self.snippets = snippets
    }
}

/// Loads/saves the user's snippets. Seeds examples on first launch.
public final class SnippetStore {
    public private(set) var snippets: [Snippet]
    private let fileURL: URL

    /// Example snippets seeded when no file exists yet.
    public static var seed: [Snippet] {
        [
            Snippet(trigger: ";date", title: "Date", body: "{date}"),
            Snippet(trigger: ";sig", title: "Signature", body: ""),
        ]
    }

    public static func defaultFileURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Toolbox", isDirectory: true)
            .appendingPathComponent("snippets.json")
    }

    public init(fileURL: URL? = nil, snippets: [Snippet]? = nil) {
        let resolvedURL = fileURL ?? Self.defaultFileURL() ?? URL(fileURLWithPath: "/dev/null")
        self.fileURL = resolvedURL
        if let snippets {
            self.snippets = snippets
            return
        }
        if let data = try? Data(contentsOf: resolvedURL),
           let file = try? JSONDecoder().decode(SnippetFile.self, from: data)
        {
            self.snippets = file.snippets
        } else if FileManager.default.fileExists(atPath: resolvedURL.path) {
            self.snippets = []
        } else {
            self.snippets = Self.seed
            save()
        }
    }

    private var isWritableURL: Bool { fileURL.path != "/dev/null" }

    public func save() {
        guard isWritableURL else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let file = SnippetFile(version: 1, snippets: snippets)
        if let data = try? JSONEncoder().encode(file) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    public func replaceAll(with snippets: [Snippet]) {
        self.snippets = snippets
        save()
    }

    /// Imports a JSON file in the snippets.json format. Returns the count.
    @discardableResult
    public func importJSON(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let file = try JSONDecoder().decode(SnippetFile.self, from: data)
        snippets.append(contentsOf: file.snippets)
        save()
        return file.snippets.count
    }

    /// Exports the current snippets for backup/sharing.
    public func exportJSON(to url: URL) throws {
        let file = SnippetFile(version: 1, snippets: snippets)
        let data = try JSONEncoder().encode(file)
        try data.write(to: url, options: .atomic)
    }
}
