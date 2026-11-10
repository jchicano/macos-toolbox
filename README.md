# Toolbox

A lightweight macOS menu bar utility app (no Dock icon). A collection of small
utilities — break reminders, keep-awake, Vim-style scrolling, auto-closing
pairs, text snippets and a color picker — each toggled from a single menu
with a checkmark. State persists across restarts.

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

| Menu item | What it does | Needs |
|---|---|---|
| Breaks | Notifies you every N minutes (snooze / skip / start now), optional full-screen overlay, pauses while idle | Notifications |
| Keep Awake | Prevents display/system sleep via a power assertion, optional auto-release duration | — |
| Vim Scroll | `Ctrl+D` / `Ctrl+U` scroll half a page in the frontmost app (skips terminals, editors, text fields) | Accessibility |
| Auto-close | Pairs `( [ { " ' \` < ¿ ¡ “ « ‘`, Tab jumps out, overtype, pair backspace, smart quotes | Accessibility |
| Snippets | Expands `;triggers` into text (`{clipboard}`, `{date}`, `{time}`, `{cursor}`), or insert from the searchable menu picker | Accessibility (expansion) |
| Color Picker | Native loupe, copies sRGB HEX / rgb() / hsl() / SwiftUI / NSColor, keeps recents | — |

Everything runs on your Mac. No accounts, no network, no telemetry.

## Requirements

- macOS 12.0 or later
- Xcode 14.2+ to build the app, [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.38+ to generate the project
- Swift 5.7+ (SwiftPM only, for `ToolboxCore` tests)

## Build

```bash
make bootstrap   # check tools (xcodegen)
make gen         # generate Toolbox.xcodeproj from project.yml
make build       # build the app (Debug)
make test        # run ToolboxCore + app tests
make universal   # Release universal binary (arm64 + x86_64)
make verify-universal  # verify architectures with lipo
make dmg         # distributable disk image (ad-hoc signed)
```

Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY=-`). On first launch,
right-click the app → Open. The Accessibility grant is invalidated on every
rebuild; remove and re-add the app in
System Settings → Privacy & Security → Accessibility, or run:

```bash
tccutil reset Accessibility com.jchicano.toolbox
```

Release signing uses a Developer ID certificate plus `notarytool`
(see `scripts/notarize.sh`; the keychain profile is created once by the
release owner and is never committed).

## Permissions

| Permission | Used by | Notes |
|---|---|---|
| Accessibility | Vim Scroll, Auto-close, Snippet expansion | Requested on first toggle with an in-app guide; see `docs/PERMISSIONS.md` |
| Notifications | Breaks | Requested when Breaks is enabled |
| Automation | Future YAML phase only | Not used by the MVP |
| Screen Recording | None | `NSColorSampler` does not require it |

The app is distributed outside the Mac App Store without sandbox, because a
global event tap (`CGEventTap`) cannot work in the sandbox. See
`docs/PERMISSIONS.md`.

## Limitations

- Dead keys on some layouts (e.g. `` ` `` on Spanish ISO) arrive without a usable key event and are left untouched.
- While Secure Input is active (password fields, etc.) key-based features go silent by design.
- `Tab`-out and synthetic arrows can misbehave in exotic editors (complex web apps, Google Docs): disable the feature or add the app to the denylist in Preferences.
- No Mac App Store build (sandbox limitation).

## Project layout

```
App/                  UI glue (menu, features, windows)
Packages/ToolboxCore  Pure logic, tested with `swift test`
Config/               Info.plist, entitlements, build settings
scripts/              universal build, DMG, notarization
docs/                 PLAN.md (internal, Spanish), MANUAL_QA.md, PERMISSIONS.md
```

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with Vorssaint or SuperBar. Feature ideas were reimplemented
from scratch with Apple's public APIs; no third-party code is included
(Yams arrives only with the optional YAML phase).
