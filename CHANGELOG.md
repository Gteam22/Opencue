# Changelog

This project follows [Semantic Versioning](https://semver.org/). The version in
`version.txt` is authoritative; `dart tool/check_version.dart` verifies that
every other copy agrees, and `test/version_consistency_test.dart` requires this
file to mention the current version.

## [Unreleased]

### Added

- **Restored the reliable FU one-shot Conversation Assist exchange.** Each
  Listen tap owns exactly one recognizer turn: listen, finalize, generate
  relevant Standard / Humorous / Flirty responses, optionally speak the primary
  response, release audio ownership and return to idle for the next tap.
  Automatic input no longer inherits the output language, accepted native
  `listening` status no longer times out merely because RMS callbacks are absent,
  and a final transcript explicitly releases a recognizer whose terminal status
  is missing. Auto Speak attempts real playback when Android's voice-availability
  probe gives a false negative, and fresh TTS no longer begins with a redundant
  cancellation. Current language support, response libraries, context, UI and
  stored data are unchanged. TTS continues to omit emoji from spoken text.
- **Radial context menu.** A gesture-driven, three-layer menu for building or
  correcting a situation with one thumb. Hold the trigger and drag to select in
  one continuous gesture, or tap to pin the menu open and browse it. Eight root
  sectors — place, people, activity, cue, atmosphere, tone, caution, finish —
  generated from the same enums the recommendation engine, the scan and the
  library filters use, so no menu option can drift from the domain model.
  Edge-aware placement, left- and right-handed layouts, Android haptics,
  Windows mouse and keyboard control, and reduced-motion support.
- **Context presets.** Saved and recent contexts, with eight starter presets
  seeded on first run. Rename, favourite, reorder and delete; a renamed starter
  preset becomes an ordinary user preset. Stored in the new `context_presets`
  table.
- **Shared context draft.** `ContextDraft` is now the single object the radial
  menu, the scan-correction path, the detailed editor and the preset loader all
  edit, with per-dimension provenance so scan-inferred, user-corrected and
  default values are distinguishable — by glyph, not by colour alone.
- **Linear accessibility fallback.** A searchable list walking the same menu
  tree, reachable from the composer and from a semantic action, so every radial
  option is available to screen-reader and keyboard users.
- **In-place context adjustment** on the recommendations screen: a chip row
  where each chip reopens the menu at its own branch, and an *Adjust* action
  that rescores without leaving the screen.
- **Library filters for activity, group size and noise level.** `OpenerLine`
  has always carried these three tag sets and the engine has always scored
  them, but `LibraryQuery` could not filter on any of them, leaving three
  tagged dimensions of every line invisible to search.
- **Settings** for radial handedness (automatic, left, right), menu haptics,
  and whether the gesture tutorial has been seen.

### Changed

- Database schema raised to **version 3**, adding `context_presets`. The
  upgrade is additive; existing lines, history and settings are untouched.

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
