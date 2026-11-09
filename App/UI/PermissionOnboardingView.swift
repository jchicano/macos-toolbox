// SPDX-License-Identifier: MIT
// Accessibility onboarding: explains, links to Settings, polls until granted.

import SwiftUI

/// Copy from the plan (§5), translated to English (public UI is English-only).
struct PermissionOnboardingView: View {
    let featureTitle: String
    var onGranted: () -> Void
    var onDismiss: () -> Void

    @State private var trusted = PermissionsService.isAccessibilityTrusted()
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toolbox needs Accessibility permission")
                .font(.headline)
            Text("For \(featureTitle) to work, Toolbox must read the keys you press and send keystrokes or scroll on your behalf. Everything happens on your Mac: nothing you type is stored or sent. macOS blocks this access automatically in password fields.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Text("1. Click Open Settings.\n2. In Privacy & Security › Accessibility, turn on Toolbox.\n3. Come back here — it activates automatically.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Settings") {
                    PermissionsService.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("Not Now") {
                    onDismiss()
                }
            }
        }
        .padding(20)
        .frame(width: 420)
        .onReceive(timer) { _ in
            let now = PermissionsService.isAccessibilityTrusted()
            trusted = now
            if now {
                onGranted()
            }
        }
    }
}
