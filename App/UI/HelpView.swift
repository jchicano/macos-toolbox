// SPDX-License-Identifier: MIT
// Help window, v0. Full version (permissions, Secure Input, README) in F7.

import SwiftUI

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toolbox")
                .font(.title)
            Text("\(String(localized: "Version")) \(HelpInfo.version) (\(HelpInfo.build)) · \(HelpInfo.architecture)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Group {
                HelpRow(
                    title: String(localized: "Breaks"),
                    detail: String(localized: "Reminds you to take a break.")
                )
                HelpRow(
                    title: String(localized: "Keep Awake"),
                    detail: String(localized: "Prevents display and sleep.")
                )
                HelpRow(
                    title: String(localized: "Vim Scroll"),
                    detail: String(localized: "Ctrl-D / Ctrl-U scroll half a page.")
                )
                HelpRow(
                    title: String(localized: "Auto-close"),
                    detail: String(localized: "Closes pairs and jumps out with Tab.")
                )
                HelpRow(
                    title: String(localized: "Snippets"),
                    detail: String(localized: "Expands short triggers into text.")
                )
                HelpRow(
                    title: String(localized: "Color Picker"),
                    detail: String(localized: "Copies the color under the cursor.")
                )
            }
            Divider()
            HStack {
                Text(String(localized: "Accessibility"))
                Spacer()
                Text(HelpInfo.accessibilityGranted ? "✅" : "❌")
            }
            .font(.caption)
        }
        .padding(20)
        .frame(minWidth: 340)
    }
}

private struct HelpRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Bundle version, running architecture and permission state for Help v0.
enum HelpInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// Machine of the running process (x86_64 under Rosetta).
    static var architecture: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    static var accessibilityGranted: Bool {
        PermissionsService.isAccessibilityTrusted()
    }
}
