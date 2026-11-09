# Permissions

## Why each permission exists

| Permission | Used by | API |
|---|---|---|
| Accessibility | Vim Scroll, Auto-close, Snippet expansion | `AXIsProcessTrustedWithOptions`, `CGEvent.tapCreate` |
| Input Monitoring | May be requested by the OS for key event taps | `CGPreflightListenEventAccess` (status only) |
| Notifications | Breaks | `UNUserNotificationCenter.requestAuthorization` |
| Screen Recording | **Nobody** | `NSColorSampler` does not need it; never requested |
| Automation | F10 only (Terminal/iTerm, dark mode via AppleScript) | `NSAppleEventsUsageDescription` |

## Notes for developers

- The app is **not sandboxed** (global event taps are sandbox-incompatible)
  and is distributed with Developer ID + notarization (ad-hoc until then).
- Rebuilding with a different signature invalidates the Accessibility grant.
  Remove and re-add the app in
  System Settings → Privacy & Security → Accessibility, or run:

```bash
tccutil reset Accessibility com.jchicano.toolbox
```

- While another app holds Secure Input, key features go silent by design.
