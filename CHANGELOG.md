# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - 2026-11-10

First MVP release: menu bar app (macOS 12+, universal arm64/x86_64) with
Breaks, Keep Awake, Vim Scroll, Auto-close, Snippets and Color Picker.
Ad-hoc signed, hardened runtime, no sandbox (event taps are incompatible
with the App Store sandbox). Live verification on Intel is recorded in
`docs/MANUAL_QA.md`; Accessibility-gated typing QA and notarization remain
pending (no Developer ID on the build machine).

### Added
- F8 packaging: `make-dmg.sh` verified (clean DMG mounts, app only),
  ad-hoc + hardened runtime confirmed on app and login helper, `notarize.sh`
  ready (keychain profile pending). `spctl` acceptance + M16 pending
  Developer ID (expected rejection without notarization).
- F7 Preferences + Help: tabbed `PreferencesView` (General, Breaks, Keep
  Awake, Vim Scroll, Auto-close with pair table, Snippets with editor +
  import/export, Color) bound to the stores with live effect, shared
  `AppFilterEditor` with `/Applications` picker, complete `HelpView`
  (per-feature docs, AX/notification state, Secure Input note, README link).
  Verified live: both windows open; 68 app tests green.
- F6 Snippets: `SnippetEngine` core (delimiter/immediate modes, longest-match,
  ";"-safe delimiters, 32-char buffer) + `SnippetTemplate` ({clipboard},
  {date}, {time}, {cursor}, {{ escape) + `SnippetStore` (versioned JSON in
  Application Support, seed, import/export) with 27 unit tests (CA-6.5);
  `SnippetsFeature` tap consumer (priority 10, trigger backspaces,
  delimiter re-emit, paste path over 200 units, per-event settings refresh,
  `Insert Snippet…` submenu + searchable picker with no-AX clipboard+HUD
  fallback). Verified live: seed file created, submenu and picker open;
  expansion typing pending AX grant (F9 M17).
- F5 Auto-close: `AutoCloseEngine` core (insert/tab-out/overtype/pair-backspace,
  smart quotes, Option-combo support for Spanish brackets, navigation/mouse/
  focus-change/timeout invalidation) with 30 unit tests (CA-4.11), plus
  `RingBuffer`; `AutoCloseFeature` tap consumer (priority 20, Unicode-based,
  denylist, editable-focus gate, dynamic `menuTitle` with active openers).
  Verified live: dynamic title renders; CA-4.x behavior pending AX grant
  (Spanish layout + latency in F9).
- F4 Vim Scroll: `ScrollVimFeature` (Ctrl+D/U only, denylist + allowlist,
  Cocoa text-field skip, half-page from cached window frame with 400 pt
  fallback, virtual event location at window center) + `ScrollPoster` (pixel
  scroll, 6-chunk smooth mode). 12 unit tests (modifiers, keycodes, filter,
  text skip, delta sign, center math); live Safari QA pending AX grant (F9
  M7/M8).
- F3 input infrastructure: `PermissionsService`, `FrontmostAppTracker`
  (atomic cached bundleID), `FocusedElementCache` (AXObserver role + window
  size, main thread only), shared `EventTapManager` (own thread, on-demand
  install/destroy, priority Snippets→AutoClose→ScrollVim, synthetic mark,
  timeout re-enable, signposts, DEBUG key logger), `TextInserter`/`KeyPoster`
  (marked Unicode/chunked paste), English `PermissionOnboardingView` with 1 s
  grant polling, ⚠️ menu warning for revoked permission. Verified live: ⚠️
  item renders, onboarding window opens; 49 tests green (Core 23, app 26).
- F2 permissionless features: `KeepAwakeFeature` (IOPM assertion, duration
  submenu, auto-release on expiry), `BreakScheduler` core (injectable clock,
  idle pause, long-absence reset) + `BreaksFeature` (30 s polling, UN
  notifications with Start/Snooze/Skip, sleep/lock observers, interval
  submenu, opt-in multi-screen overlay), `ColorPickerAction` (`NSColorSampler`,
  sRGB, clipboard, format + recents submenus, HUD). Verified live on Intel:
  CA-2.1/2.2/2.4 (`pmset` shows/releases assertion, checkmark persists across
  restart), 25.6 MB RSS.
- F1 core and catalog: versioned `Settings` + `SettingsStore` (JSON, backup on
  corruption), `Feature` protocol + `FeatureCatalog` + permission-gating
  `FeatureRegistry` (idempotent start/stop, `stopAll` on terminate), menu built
  from the catalog with checks, Help v0 window, Preferences placeholder,
  hybrid Launch at Login (`SMAppService` on macOS 13+, `ToolboxLoginItem`
  helper embedded at `Contents/Library/LoginItems` on macOS 12), English
  `Localizable.strings`. 25 tests (Core 10, app 15).

### Added
- F0 bootstrap: XcodeGen project, `ToolboxCore` Swift package, menu-bar app
  skeleton with a Quit item, universal build scripts.
