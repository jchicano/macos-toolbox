# Permissions

## Why each permission exists

| Permission | Used by | API |
|---|---|---|
| Accessibility | Auto-close, Snippet expansion | `AXIsProcessTrustedWithOptions`, `CGEvent.tapCreate` |
| Input Monitoring | May be requested by the OS for key event taps | `CGPreflightListenEventAccess` (status only) |
| Notifications | Breaks | `UNUserNotificationCenter.requestAuthorization` |
| Screen Recording | **Nobody** | `NSColorSampler` does not need it; never requested |
| Automation | F10 only (Terminal/iTerm, dark mode via AppleScript) | `NSAppleEventsUsageDescription` |

## Notes for developers

- The app is **not sandboxed** (global event taps are sandbox-incompatible)
  and is ad-hoc signed, without Developer ID or notarization (internal tool,
  M16 out of scope).
- Rebuilding with a different signature invalidates the Accessibility grant.
  The system prompt adds the app to
  System Settings → Privacy & Security → Accessibility; enabling the switch
  resumes Auto-close and Snippets in the running app without a relaunch. To
  start over:

```bash
tccutil reset Accessibility com.jchicano.toolbox
```

  Note that `tccutil reset` is not observed by an already-running process:
  relaunch the app after resetting it.

- While another app holds Secure Input, key features go silent by design.
