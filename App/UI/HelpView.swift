// SPDX-License-Identifier: MIT
// Complete Help: what each utility does, permission state, Secure Input, README.

import SwiftUI
import UserNotifications

struct HelpView: View {
    var body: some View {
        ScrollView {
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
                        detail: String(localized: "Reminds you to take a break. Needs notification permission when enabled.")
                    )
                    HelpRow(
                        title: String(localized: "Keep Awake"),
                        detail: String(localized: "Prevents display and system sleep via a power assertion.")
                    )
                    HelpRow(
                        title: String(localized: "Auto-close"),
                        detail: String(localized: "Closes pairs and jumps out with Tab. Needs Accessibility. Disabled in IDEs and password fields.")
                    )
                    HelpRow(
                        title: String(localized: "Snippets"),
                        detail: String(localized: "Expands short triggers into text, or insert from the menu. Needs Accessibility for expansion.")
                    )
                    HelpRow(
                        title: String(localized: "Color Picker"),
                        detail: String(localized: "Copies the color under the cursor. Never asks for Screen Recording.")
                    )
                }
                Divider()
                Group {
                    Text(String(localized: "Permissions")).font(.headline)
                    PermissionRow(
                        name: String(localized: "Accessibility"),
                        granted: HelpInfo.accessibilityGranted,
                        hint: HelpInfo.accessibilityGranted
                            ? nil
                            : String(localized: "Enable an Auto-close or Snippets feature to be guided.")
                    )
                    PermissionRow(
                        name: String(localized: "Notifications"),
                        granted: HelpInfo.notificationsGranted,
                        hint: HelpInfo.notificationsGranted
                            ? nil
                            : String(localized: "Enable Breaks to be asked.")
                    )
                    if HelpInfo.secureInputEnabled {
                        HStack {
                            Text("⚠️")
                            Text(String(localized: "Secure Input is on — key features stay silent in password fields."))
                                .font(.caption)
                        }
                    }
                }
                Divider()
                Link(String(localized: "README and source code"), destination: HelpInfo.readmeURL)
                    .font(.caption)
            }
            .padding(20)
            .frame(minWidth: 360)
        }
        .frame(maxHeight: 520)
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

private struct PermissionRow: View {
    let name: String
    let granted: Bool
    let hint: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name)
                Spacer()
                Text(granted ? "✅" : "❌")
            }
            .font(.caption)
            if let hint {
                Text(hint).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Bundle version, running architecture and permission state for Help.
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

    /// Synchronous snapshot (updated on next Help open).
    static var notificationsGranted: Bool {
        notificationCache
    }

    private static var notificationCache = false

    /// Refresh the notification state (async API). Call when opening Help.
    static func refreshNotificationState(completion: @escaping () -> Void = {}) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            notificationCache = settings.authorizationStatus == .authorized
            DispatchQueue.main.async { completion() }
        }
    }

    static var secureInputEnabled: Bool {
        PermissionsService.isSecureInputEnabled()
    }

    static var readmeURL: URL {
        URL(string: "https://github.com/jchicano/macos-toolbox")!
    }
}
