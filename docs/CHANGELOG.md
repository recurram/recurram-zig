# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- GitHub issue templates (feature request and bug report), pull request template, and PR message validation workflow.
- `src/v2.zig` module; public `encode` and `decode` now route through the v2 codec path by default.

### Changed

- Renamed the project from Recurram to Twilic. Historical changelog entries still refer to Recurram where applicable.

### Fixed

- Updated `build.zig.zon` package fingerprint after dependency changes.

## [2.0.0] - 2026-05-01

### Changed

- Project version bumped to `2.0.0` for alignment with the Recurram v2 release line.
- Documentation updated to point to the v2 active specification profile.
