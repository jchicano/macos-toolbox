// SPDX-License-Identifier: MIT
// Searchable snippet picker (Insert Snippet…).

import SwiftUI
import ToolboxCore

/// Fuzzy filter: case-insensitive trigger/title match, trigger-prefix first.
/// A leading ";" is ignored for prefix matching so "sig" finds ";sig".
func filterSnippets(_ snippets: [Snippet], query: String) -> [Snippet] {
    let query = query.trimmingCharacters(in: .whitespaces).lowercased()
    guard !query.isEmpty else { return snippets.filter(\.enabled) }
    func normalized(_ trigger: String) -> String {
        let lower = trigger.lowercased()
        return lower.hasPrefix(";") ? String(lower.dropFirst()) : lower
    }
    let candidates = snippets.filter(\.enabled)
    let prefixed = candidates
        .filter { normalized($0.trigger).hasPrefix(query) }
        .sorted { $0.trigger.count < $1.trigger.count }
    let others = candidates.filter {
        !normalized($0.trigger).hasPrefix(query)
            && ($0.trigger.lowercased().contains(query) || $0.title.lowercased().contains(query))
    }
    return prefixed + others
}

struct SnippetPickerView: View {
    @State private var query = ""
    let snippets: [Snippet]
    var onPick: (Snippet) -> Void

    var body: some View {
        VStack(spacing: 8) {
            TextField("Search snippets", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { pickFirst() }
            List(filterSnippets(snippets, query: query)) { snippet in
                Button {
                    onPick(snippet)
                } label: {
                    VStack(alignment: .leading) {
                        Text(snippet.trigger).font(.headline)
                        Text(snippet.title).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(minWidth: 320, minHeight: 300)
    }

    private func pickFirst() {
        if let first = filterSnippets(snippets, query: query).first {
            onPick(first)
        }
    }
}
