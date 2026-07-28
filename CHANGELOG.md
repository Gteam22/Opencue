# Changelog

This project follows [Semantic Versioning](https://semver.org/). The version in
`version.txt` is authoritative; `dart tool/check_version.dart` verifies that
every other copy agrees, and `test/version_consistency_test.dart` requires this
file to mention the current version.

## [0.1.0] — First working version

The first complete build: a Windows desktop application with a local library, a
deterministic recommendation engine, and an installer.

### Added

- **Library.** 155 starter lines across 22 situations, each with the Japanese
  text, an English meaning, the locations, cues, group sizes, noise levels and
  tones it suits, a 1–5 directness rating, and explicit use and avoid
  conditions. Add, edit, duplicate, delete, favourite, search across both
  languages, filter by six dimensions, and sort four ways.
- **Situation builder.** Manual entry of location, activity, group size, noise
  level and observable cues, plus eye contact, whether a conversation has
  started, and the five conditions that stop suggestions.
- **Recommendation engine.** Deterministic, local, and independent of Flutter.
  Returns up to three suggestions — safest, playful, more direct — with the
  reasons each one matched, and a score breakdown available behind a debug
  toggle. Excludes conflicting lines outright, prefers short lines in loud
  venues, avoids single-person lines when companions are present, honours a
  requested directness, and rotates so repeated rounds do not return the same
  three lines.
- **Approach advisory.** When the described situation suggests an approach would
  be unwelcome, the app says so prominently, names the specific conditions that
  triggered it, and offers graceful exits instead of openers.
- **History.** Record whether a line was used and how it went, with an optional
  private note. Aggregate figures, outcome distribution, and the situations you
  use most. Proportions appear only above 8 recorded outcomes and per-line
  rankings only above 12, so small samples are shown as counts.
- **Import and export.** Versioned JSON with a documented schema, a
  merge-or-replace choice, duplicate-id re-keying, validation that never throws
  on malformed input, and readable error messages. History is excluded from
  exports by default. A working example lives at
  `assets/sample/sample_import.json`.
- **Settings.** Japanese, English or bilingual display; light, dark or system
  theme; a default directness; restore the starter library; clear history; reset
  all data. Every destructive action confirms first, and resetting everything
  confirms twice.
- **About and privacy screen** stating in plain terms that all data is local,
  that this version reads no camera and no microphone, that nothing about anyone
  else is profiled, and that a future scan feature would describe the
  environment rather than judge interest or consent.
- **Windows installer.** A single `OpenCue-Setup.exe`: per-user, no
  administrator rights, Start menu entry, optional desktop shortcut,
  uninstaller, and an offer to launch on completion. The database lives in
  `%APPDATA%\OpenCue`, never in the installation folder, so upgrades cannot
  disturb it.
- **CI.** A Windows workflow that checks version consistency, verifies
  formatting, analyses, tests, builds the release bundle, locates Flutter's
  output directory dynamically, compiles the installer, and uploads
  `OpenCue-Setup.exe`. Tags matching `v*.*.*` publish a GitHub Release with the
  installer attached.

### Known limitations

- Windows only. No Android build has been attempted.
- No camera, smart-glasses or audio context input. The `ContextProvider`
  interface is in place and `ContextSource` already deserializes the future
  values, but only `ManualContextProvider` exists, and no sensor package is
  declared.
- Search is `LIKE`-based, with no kana folding, romaji matching or stemming.
- The engine uses a line's overall personal record, not its record in a
  particular kind of venue.
- The rotation window is session-only and resets when the app restarts.
- The installer is not code-signed, so Windows SmartScreen warns on first run.
  The `SignTool` directives are present but commented.
- `PUBLISHER_PLACEHOLDER` and the `OWNER` repository URL must be replaced before
  publishing.
