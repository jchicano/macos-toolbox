# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
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
