// SPDX-License-Identifier: MIT
// Placeholder until the full Preferences window lands in F7.

import SwiftUI

struct PreferencesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Toolbox Preferences")
                .font(.headline)
            Text(String(localized: "Full preferences land in F7."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(minWidth: 300)
    }
}
