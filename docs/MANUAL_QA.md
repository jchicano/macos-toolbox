# Manual QA checklist

Per the plan (§10.2), every check runs on **Intel** and **Apple Silicon**.
This machine is Intel / macOS 12: fill the Intel column; ARM stays pending.

| # | Test | Intel | ARM |
|---|---|---|---|
| M1 | App starts with no Dock icon; menu bar icon appears | ☐ | ☐ |
| M2 | Menu order and titles match §0, in English; checks persist | ☐ | ☐ |
| M3 | Keep Awake: `pmset -g assertions` appears/vanishes; duration works | ☐ | ☐ |
| M4 | Breaks: notification, snooze, skip, idle/screen-lock pause | ☐ | ☐ |
| M5 | Color picker: correct hex, Esc cancels, recents, no screen-recording prompt | ☐ | ☐ |
| M6 | Accessibility onboarding: deny → not enabled; grant → auto-enabled | ☐ | ☐ |
| M7 | Vim Scroll: Safari, Chrome, Mail, Finder list, Notes outside text fields | ☐ | ☐ |
| M8 | Vim Scroll: Terminal/iTerm/VS Code unaffected; `^D` in text field deletes | ☐ | ☐ |
| M9 | Auto-close: CA-4.1–4.7 in TextEdit, Notes, Slack, browser text fields | ☐ | ☐ |
| M10 | Auto-close with Spanish – ISO layout: `¿ ¡ ( [ { " ' dead-key backtick` | ☐ | ☐ |
| M11 | Auto-close inactive in VS Code, Xcode, Terminal, password fields | ☐ | ☐ |
| M12 | Revoke Accessibility while running → ⚠️ menu warning, input not blocked | ☐ | ☐ |
| M13 | Sleep/wake: event tap still works, timers rescheduled | ☐ | ☐ |
| M14 | Activity Monitor: < 30 MB, ~0% CPU idle with all features on | ☐ | ☐ |
| M15 | Quit: no assertions or processes left | ☐ | ☐ |
| M16 | (F8) Notarized: DMG opens on a fresh account without Gatekeeper warnings | ☐ (pending Developer ID) | ☐ |
| M17 | Snippets: `;sig` in TextEdit/Notes/Slack/Safari; variables; picker; no-AX fallback | ☐ | ☐ |
| M18 | (F10) Edit/Reload config, YAML errors, bookmarks, workspaces, run_terminal, dark mode, `include:` | ☐ | ☐ |

## Results log

| Date | Phase | Arch | Result | Notes |
|---|---|---|---|---|
| | | | | |
