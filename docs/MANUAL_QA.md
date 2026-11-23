# Manual QA checklist

Per the plan (§10.2), every check runs on **Intel** and **Apple Silicon**.
This machine is Intel / macOS 12: fill the Intel column; ARM stays pending.

| # | Test | Intel | ARM |
|---|---|---|---|
| M1 | App starts with no Dock icon; menu bar icon appears | ☑ | ☐ |
| M2 | Menu order and titles match §0, in English; checks persist | ☑ | ☐ |
| M3 | Keep Awake: `pmset -g assertions` appears/vanishes; duration works | ☑ (appear/vanish + 8 s auto-expiry verified) | ☐ |
| M4 | Breaks: notification, snooze, skip, idle/screen-lock pause | ☑ (notification ✓; overlay Skip + Snooze verified 2026-11-12; idle/lock pause unit-tested) | ☐ |
| M5 | Color picker: correct hex, Esc cancels, recents, no screen-recording prompt | ☑ (loupe ✓, Esc ✓, formats ✓, recents ✓, no Screen Recording ✓; `#EEEEEE` sampled and copied) | ☐ |
| M6 | Accessibility onboarding: deny → not enabled; grant → auto-enabled | ☑ (deny: no enable + onboarding shown; grant: features auto-start) | ☐ |
| M7 | Vim Scroll: removed at user request | N/A (removed) | N/A |
| M8 | Vim Scroll: removed at user request | N/A (removed) | N/A |
| M9 | Auto-close: CA-4.1–4.7 in TextEdit, Notes, Slack, browser text fields | ☑ (TextEdit full pass 2026-11-11; Notes + Safari verified 2026-11-23: pairs, Tab-out, pair backspace, overtype and Spanish `¿¡`; Slack N/A — not installed) | ☐ |
| M10 | Auto-close with Spanish – ISO layout | ☑ (`¿?`, quotes, backtick pair verified; dead-key ` remains pass-through by design) | ☐ |
| M11 | Auto-close inactive in VS Code, Xcode, Terminal, password fields | ☑ (VS Code + Terminal verified; password fields by design) | ☐ |
| M12 | Revoke Accessibility while running → ⚠️ menu warning, input not blocked; re-grant resumes without relaunch | ☑ (no freeze after fix; ⚠️ shown; typing unaffected; monitor resumes on grant) | ☐ |
| M13 | Sleep/wake: event tap still works, timers rescheduled | ☐ | ☐ |
| M14 | Activity Monitor: < 30 MB, ~0% CPU idle with all features on | ☑ (16.8 MB RSS, 0.0% CPU with Breaks + Keep Awake + Auto-close + Snippets) | ☐ |
| M15 | Quit: no assertions or processes left | ☑ | ☐ |
| M16 | (F8) Notarized | N/A (internal tool, no distribution) | N/A |
| M17 | Snippets: `;sig` in TextEdit; variables; picker; no-AX fallback | ☑ (`;sig`/`;date` ✓, `{cursor}` → `aXb` ✓, picker insert ✓; no-AX fallback copies + HUD ✓) | ☐ |
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
| 2026-11-13 | Live QA | Intel | M12 pass (auto-resume) | System prompt listed the app; enabling the switch started Auto-close + Snippets in the running app, no relaunch |
| 2026-11-13 | Live QA | Intel | M17 pass (typing) | `(` → `()` in TextEdit after the self-service grant |
| 2026-11-16 | Live QA | Intel | M14 pass (all features) | 16.8 MB RSS, 0.0% CPU idle; Keep Awake assertion visible in `pmset` |
| 2026-11-16 | Live QA | Intel | M5 partial | Loupe shows, Esc cancels, formats and recents work; found and fixed the unreachable Color Picker action |
| 2026-11-16 | Live QA | Intel | M5 bug fixed | AppKit skips the action of an item with a submenu; sampler must be retained and the app activated |
| 2026-11-16 | Live QA | Intel | M5 pass | Physical click sampled `#EEEEEE`; copied to the clipboard and added to Recent |
| 2026-11-23 | Live QA | Intel | M17 pass (no-AX fallback) | With Accessibility revoked and the app relaunched: `;sig` copied `Best`, `;date` copied `2026-11-23`, HUD shown, no paste attempt |
| 2026-11-23 | Live QA | Intel | M9 partial (Notes) | HID helper (not AppleScript) drives the tap: `(` → `()`, `[` + Tab + `X` → `[]X`; Slack is not installed |
| 2026-11-23 | Live QA | Intel | M9 pass (Safari) | With Safari active and the textarea focused: `(` → `()`, `[` + Tab + `X` → `[]X`, `{` + backspace → empty, overtype `(` `)` `X` → `()X`, `'` → `''`, `¿` → `¿?`, `¡` → `¡!` |
| 2026-11-23 | Live QA | Intel | M12 re-confirmed | After the no-AX test, enabling the switch installed the tap in the same process (pid 6454), no relaunch |
| 2026-11-23 | Live QA | Intel | M15 re-confirmed | Quit leaves no process or power assertion; relaunch restores the tap from persisted settings |

## Pending QA gaps

Everything else (M1–M12, M14, M15, M17 on Intel) is closed. What remains needs
either a sleep cycle or Apple Silicon hardware. None of these gaps blocks the
internal release; they are tracked here so they are not silently forgotten.

### M13 — Sleep/wake

1. With Auto-close and Snippets enabled, put the Mac to sleep and wake it.
2. Check that the event tap is reinstalled (`log show --predicate 'subsystem ==
   "com.jchicano.toolbox" AND category == "eventtap"'`) and that typing still
   expands/auto-closes.
3. If Keep Awake or Breaks were active, check that their timers were
   rescheduled and that the break overlay still appears.

Why it is pending: it requires a real sleep/wake cycle on this machine; the
timer rescheduling paths are unit-tested but the tap reinstall after wake is
not.

### ARM (Apple Silicon) pass

The `dist/Toolbox.app` build is universal (`x86_64 arm64`) but only Intel /
macOS 12 has been exercised. On an Apple Silicon Mac, repeat at minimum M1,
M2, M3, M5, M6, M9, M12, M14 and M15 and fill the ARM column above. Until then
the ARM column stays `☐`.

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
