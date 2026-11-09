# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
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
