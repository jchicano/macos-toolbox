# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
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
