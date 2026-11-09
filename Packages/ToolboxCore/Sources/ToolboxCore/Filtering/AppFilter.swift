// SPDX-License-Identifier: MIT
// Per-app scoping for input features (denylist or allowlist).

public struct AppFilter: Codable, Equatable {
    public enum Mode: String, Codable {
        case denylist
        case allowlist
    }

    public var mode: Mode
    /// Bundle identifiers. A trailing ".*" matches a prefix (e.g. "com.jetbrains.*").
    public var bundleIDs: [String]

    public init(mode: Mode, bundleIDs: [String]) {
        self.mode = mode
        self.bundleIDs = bundleIDs
    }

    /// Fail-open for unknown apps on denylists, fail-closed on allowlists.
    public func allows(_ bundleID: String?) -> Bool {
        guard let bundleID else {
            return mode == .denylist
        }
        let blocked = bundleIDs.contains { entry in
            if entry.hasSuffix(".*") {
                return bundleID.hasPrefix(entry.dropLast(1))
            }
            return bundleID == entry
        }
        switch mode {
        case .denylist: return !blocked
        case .allowlist: return blocked
        }
    }

    // MARK: - Defaults (plan §6.3 / §6.4)

    public static let defaultScrollDeny = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.github.wez.wezterm",
        "dev.warp.Warp-Stable",
        "org.vim.MacVim",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",
        "com.jetbrains.*",
        "dev.zed.Zed",
        "org.gnu.Emacs",
    ]

    public static let defaultAutoCloseDeny = defaultScrollDeny + [
        "com.sublimetext.4",
        "com.panic.Nova",
        "com.barebones.bbedit",
        "md.obsidian",
        "notion.id",
    ]
}
