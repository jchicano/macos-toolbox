# Toolbox

A lightweight macOS menu bar utility app (no Dock icon). A collection of small
utilities — breaks reminders, keep-awake, Vim-style scrolling, auto-closing
pairs, text snippets and a color picker — each toggled from a single menu.

> Status: early bootstrap (F0). Features land incrementally; see
> `docs/PLAN.md` for the full implementation plan.

## Requirements

- macOS 12.0 or later (Monterey and newer)
- Xcode 14.2+ to build the app (`xcodegen` to generate the project)
- Swift 5.7+ (SwiftPM only, for `ToolboxCore` tests)

## Build

```bash
make bootstrap   # check tools (xcodegen)
make gen         # generate Toolbox.xcodeproj from project.yml
make build       # build the app (Debug)
make test        # run ToolboxCore + app tests
make universal   # Release universal binary (arm64 + x86_64)
make verify-universal  # verify architectures with lipo
```

Local builds use ad-hoc signing (`CODE_SIGN_IDENTITY=-`). Right-click → Open
on first launch. Granting Accessibility permission is invalidated on every
rebuild; remove and re-add the app, or run:

```bash
tccutil reset Accessibility com.jchicano.toolbox
```

## Permissions

| Permission | Used by | Notes |
|---|---|---|
| Accessibility | Vim Scroll, Auto-close, Snippet expansion | Requested on first toggle; see `docs/PERMISSIONS.md` |
| Notifications | Breaks | Requested when Breaks is enabled |
| Screen Recording | None | `NSColorSampler` does not require it |

The app is distributed outside the Mac App Store (no sandbox) because global
event taps are not allowed in the sandbox. See `docs/PERMISSIONS.md`.

## Limitations

- Dead keys on some layouts (e.g. `` ` `` on Spanish ISO) may not auto-close.
- Secure Input fields (passwords) block global key monitoring by design.
- No Mac App Store build (sandbox limitation).

## License

MIT — see [LICENSE](LICENSE). Not affiliated with Vorssaint or SuperBar.
