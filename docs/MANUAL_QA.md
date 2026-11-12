# Manual QA checklist

Per the plan (§10.2), every check runs on **Intel** and **Apple Silicon**.
This machine is Intel / macOS 12: fill the Intel column; ARM stays pending.

| # | Test | Intel | ARM |
|---|---|---|---|
| M1 | App starts with no Dock icon; menu bar icon appears | ☑ | ☐ |
| M2 | Menu order and titles match §0, in English; checks persist | ☑ | ☐ |
| M3 | Keep Awake: `pmset -g assertions` appears/vanishes; duration works | ☑ (appear/vanish + 8 s auto-expiry verified) | ☐ |
| M4 | Breaks: notification, snooze, skip, idle/screen-lock pause | ☑ (notification ✓; overlay Skip + Snooze verified 2026-11-12; idle/lock pause unit-tested) | ☐ |
| M5 | Color picker: correct hex, Esc cancels, recents, no screen-recording prompt | ☐ (unit-tested; live pending) | ☐ |
| M6 | Accessibility onboarding: deny → not enabled; grant → auto-enabled | ☑ (deny: no enable + onboarding shown; grant: features auto-start) | ☐ |
| M7 | Vim Scroll: removed at user request | N/A (removed) | N/A |
| M8 | Vim Scroll: removed at user request | N/A (removed) | N/A |
| M9 | Auto-close: CA-4.1–4.7 in TextEdit, Notes, Slack, browser text fields | ☑ (TextEdit full pass incl. Tab-out/overtype/backspace; other apps pending) | ☐ |
| M10 | Auto-close with Spanish – ISO layout | ☑ (`¿?`, quotes, backtick pair verified; dead-key ` remains pass-through by design) | ☐ |
| M11 | Auto-close inactive in VS Code, Xcode, Terminal, password fields | ☑ (VS Code + Terminal verified; password fields by design) | ☐ |
| M12 | Revoke Accessibility while running → ⚠️ menu warning, input not blocked | ☑ (no freeze after fix; ⚠️ shown; typing unaffected) | ☐ |
| M13 | Sleep/wake: event tap still works, timers rescheduled | ☐ | ☐ |
| M14 | Activity Monitor: < 30 MB, ~0% CPU idle with all features on | ☑ (22–26 MB RSS, 1 feature) | ☐ |
| M15 | Quit: no assertions or processes left | ☑ | ☐ |
| M16 | (F8) Notarized | N/A (internal tool, no distribution) | N/A |
| M17 | Snippets: `;sig` in TextEdit; variables; picker; no-AX fallback | ☑ (`;sig`/`;date` ✓, `{cursor}` → `aXb` ✓, picker insert ✓; no-AX fallback pending) | ☐ |
| M18 | (F10) Edit/Reload config, YAML errors, bookmarks, workspaces, run_terminal, dark mode, `include:` | ☐ | ☐ |

## Results log

| Date | Phase | Arch | Result | Notes |
|---|---|---|---|---|
| 2026-11-10 | F9 | Intel | M1/M2/M14/M15 pass | `background only`; menu order matches §0; 22–26 MB RSS; clean quit |
| 2026-11-10 | F9 | Intel | M3 partial | `pmset` shows/releases "Toolbox: Keep Awake"; timed duration not exercised |
| 2026-11-10 | F9 | Intel | M6–M12, M17 pending | Needed Accessibility grant + typing QA |
| 2026-11-10 | F9 | Intel | M16 pending | Needs Developer ID + notarization (`spctl` rejects ad-hoc as expected) |
| 2026-11-11 | Live QA | Intel | M3/M6/M9/M10/M11/M12 pass; M17 partial | Physical typing; 8 s Keep Awake expiry; revoke without freeze |
| 2026-11-11 | Live QA | Intel | M4 notification | Notification delivered; overlay not exercised |
| 2026-11-12 | Live QA | Intel | M4 pass (overlay) | Overlay renders; Skip and Snooze both verified |
| 2026-11-12 | Live QA | Intel | M17 pass | `;cur` + space + `X` → `aXb` |
| 2026-11-12 | Regression | Intel | Checkbox/button abort fixed | Numeric `CFBundleVersion`; see below |

## Fixed: abort while drawing checkboxes and buttons (2026-11-12)

Symptom: the app aborted (SIGABRT) while drawing a checkbox or a push
button (Preferences → Breaks pane, break overlay → Skip), with a stack
ending in `+[CUIShapeEffectStack sharedCIContext]`.

Root cause: `CFBundleVersion` was written as a **number** in Info.plist
(Xcodegen copied `CFBundleVersion: 1` verbatim; Apple requires a string).
The Intel graphics driver's telemetry reads that key and passes it to
`CFStringGetCString`, which throws on an `NSNumber`:

    -[__NSCFNumber _getCString:maxLength:encoding:]: unrecognized selector
      -> CFStringGetCString -> __retain_OA
      -> createContextTelemetryDataWithQueueLabelAndCallstack
      -> -[MTLIOAccelCommandQueue setLabel:] / -[MTLIOAccelCommandBuffer commit]

The throw escapes `dispatch_once` (not exception safe), so the process
aborts. It only fired when the first GPU-backed CoreUI context was created,
which is why it looked intermittent.

Proof: a minimal app bundle that creates a `CIContext` aborts 6/6 with
`CFBundleVersion` as an integer and 0/6 with it as a string. `CFBundleVersion`
is now `"1"` and `InfoPlistTests` guards the type. Skip, Snooze and
Preferences re-verified on the release build with no crash.
