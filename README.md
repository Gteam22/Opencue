# OpenCue

A personal library of Japanese conversation openers with an offline
recommendation engine. You describe the situation you are actually in, and
OpenCue suggests a few lines that fit it — or tells you that this is probably not
a good moment to say anything.

Everything runs locally. There is no account, no server, no camera, no
microphone, and no network code anywhere in the application.

---

## For users

### What it does

- Holds a library of openers, each with the Japanese line and its English
  meaning, plus the situations it suits and the situations it does not.
- Lets you describe where you are and what you can see, and returns up to three
  suggestions: a **safest** one, a **playful** one and a **more direct** one.
- Warns you, prominently, when the situation you described suggests approaching
  would be unwelcome — and in that case offers graceful exits instead of
  openers.
- Records whether you used a line and how it went, with an optional private
  note, so over time you can see what actually works for you.
- Ships with 155 starter lines across 22 situations, and you can add, edit,
  duplicate, delete, search, filter and favourite freely.

### What it deliberately does not do

- It never guarantees a reception, and it does not score or rate other people.
- It stores nothing about anyone's appearance, availability, or interest — only
  the situation you typed in.
- It has no camera or microphone access. A later version may read environmental
  context from a camera or smart glasses; that would describe the *setting*, and
  it would never claim to determine whether someone is interested or consenting.

### Getting the installer

The installer is built by GitHub Actions on a Windows runner, so you never need
any development tools.

**From a release (recommended):** open the repository's **Releases** page, pick
the latest version, and download `OpenCue-Setup.exe` from the assets list.

**From a build:** open the **Actions** tab, click the most recent successful
**Build Windows installer** run, scroll to **Artifacts**, and download
`OpenCue-Setup-exe`. It arrives as a `.zip`; the `OpenCue-Setup.exe` inside it is
the installer. (GitHub always zips artifacts — that is GitHub's doing, not an
extra packaging step.)

### Installing

1. Double-click `OpenCue-Setup.exe`.
2. Windows may show a "Windows protected your PC" warning, because the installer
   is not yet code-signed. Choose **More info**, then **Run anyway**. (See
   *Code signing* below for why, and how to remove this.)
3. Follow the wizard. It installs for your user account only and does not ask
   for administrator rights.
4. Optionally tick **Create a desktop shortcut**.
5. Tick **Launch OpenCue** on the last page, or start it later from the Start
   menu.

### Where your data is stored

```
%APPDATA%\OpenCue\opencue.db
```

Paste `%APPDATA%\OpenCue` into the address bar of File Explorer to open it. This
is a normal SQLite file in your user profile, deliberately **not** in the
installation folder, which is what allows an upgrade to replace the program
without touching your lines, notes or history.

### Backing up

**Settings → Your data → Export data** writes a single JSON file containing your
own lines, your favourites and your settings. Interaction history is *excluded by
default*, because the notes attached to it are the most personal thing the app
holds; there is a switch to include it if you want a complete backup.

**Import data** reads such a file back, and asks whether to add to your library
or replace it. A malformed or partial file is reported with a readable
explanation rather than crashing, and anything unreadable inside it is skipped
with a note rather than taking the whole import down.
`assets/sample/sample_import.json` in this repository is a working example of the
format.

### Upgrading

Run the newer `OpenCue-Setup.exe`. It replaces the installed files in place. Your
database is in `%APPDATA%` and is not touched.

### Uninstalling

**Settings → Apps → Installed apps → OpenCue → Uninstall**, or use the entry in
the Start menu folder.

The uninstaller removes the program but **leaves your database alone on
purpose** — uninstalling should not silently destroy notes you may want. To
remove your data as well, delete the `%APPDATA%\OpenCue` folder afterwards.
Export a backup first if there is any chance you want it later.

---

## For developers

### Prerequisites

- Flutter **3.27** or newer on the stable channel (Dart 3.6+). `Color.withValues`
  and `PopScope.onPopInvokedWithResult` require this; `pubspec.yaml` states the
  constraint.
- Visual Studio 2022 with the **Desktop development with C++** workload, for the
  Windows toolchain. `flutter doctor` will confirm.
- **Inno Setup 6** to compile the installer locally (`choco install innosetup`).
- Python 3.10+ with `pillow`, only to re-run the generators in `tool/`.

### Everyday commands

```bash
flutter pub get
flutter run -d windows                 # run it
flutter test                           # the whole suite
dart format --output=none --set-exit-if-changed .
flutter analyze
dart tool/check_version.dart           # version agreement across four files
python3 tool/check_strings_used.py     # every l10n key a widget asks for exists
python3 tool/check_dart_sanity.py      # structural checks on the Dart sources
python3 tool/check_dart_symbols.py     # internal imports all resolve and are used
python3 tool/check_lint_risks.py       # approximates the escalated lints
python3 tool/check_installer.py        # structural checks on the Inno Setup script
```

The last four are cheap Python checks that run in CI before the Dart toolchain
is touched. They are not a substitute for `flutter analyze`; they exist because
they catch a specific, common class of mistake in about a second.

### The `windows/` directory

`windows/` is **not committed**. It is generated boilerplate — a C++ runner, a
CMake build, and a Win32 resource file — that `flutter create` writes from the
project name in `pubspec.yaml`. Before building, run:

```bash
flutter create --platforms=windows --project-name opencue .
```

Because the project name is `opencue`, this produces `opencue.exe`, which is the
name `installer/opencue.iss` expects. The CI workflow runs the same command when
the directory is absent, then copies `assets/icons/opencue.ico` over
`windows/runner/resources/app_icon.ico` — the runner compiles whatever icon sits
at that path into the executable, so replacing that one file is the whole of icon
customisation.

If you ever need to hand-edit the runner (to change the window title, say), drop
`/windows/` from `.gitignore` and commit the directory; the workflow leaves an
existing `windows/runner/CMakeLists.txt` untouched.

### Building a release and an installer

```bash
flutter create --platforms=windows --project-name opencue .   # first time only
flutter build windows --release
# Then point Inno Setup at whatever directory that actually produced:
iscc /DBuildDir="build\windows\x64\runner\Release" installer\opencue.iss
```

The result is `installer/Output/OpenCue-Setup.exe`.

`BuildDir` is a parameter rather than a constant because Flutter's Windows output
path has changed between versions and depends on the target architecture
(`build\windows\x64\runner\Release` on current stable, `build\windows\runner\
Release` on older ones, `arm64` on ARM). The workflow searches for `opencue.exe`
under `build\windows` and passes the directory it finds, so nothing hard-codes a
path that will quietly go stale. If the bundle is missing, the script stops with
an explanatory `#error` instead of building an installer with no program in it.

### Triggering the workflow

`.github/workflows/build-windows-installer.yml` runs on pushes to `main`, on pull
requests, on `workflow_dispatch` (**Actions → Build Windows installer → Run
workflow**), and on tags matching `v*.*.*`. Only a tag build publishes a GitHub
Release with the installer attached:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

### Repository structure

```
lib/
  main.dart               Entry point. Assembles the object graph, nothing else.
  app.dart                Root widget, theme wiring, responsive shell.
  core/                   App identity, paths, ids, theme. No business logic.
  domain/                 Pure Dart. No Flutter import anywhere below here.
    enums/                Every controlled vocabulary.
    models/               OpenerLine, ContextSnapshot, InteractionRecord, settings.
    recommendation/       The scoring engine and its result types.
    context/              ContextProvider interface + ManualContextProvider.
    repositories/         Storage interfaces and the library query object.
  data/                   Storage and services.
    db/                   Schema, creation, migrations.
    repositories/         SQLite implementations of the domain interfaces.
    seed/                 The embedded starter library and its loader.
    transfer/             Versioned JSON import and export.
  features/               UI, one folder per screen, plus shared/.
  l10n/                   Generated EN/JA tables and the lookup class.
test/                     Unit, integration and widget tests.
tool/                     Generators and checkers. Not shipped.
installer/                Inno Setup script. Imported by nothing in lib/.
assets/                   Icons and the sample import file.
```

The dependency direction is one-way: `features` → `data` → `domain`. The domain
layer has no Flutter dependency, which is what lets the engine be tested
directly and reused on Android later. The installer knows about the app; the app
knows nothing about the installer.

### Database schema

Current version: **2**. `%APPDATA%\OpenCue\opencue.db`.

| Table | Purpose |
| --- | --- |
| `opener_lines` | One row per line. Tag sets are stored as comma-separated enum names. |
| `interactions` | One row per recorded use. `context_snapshot` is a JSON blob; `opener_line_id` cascades on delete. |
| `settings` | Key/value. |

Tag sets are denormalised into text columns rather than given join tables. The
library is a few hundred rows read entirely into memory at launch, so a join
table would add schema and migration surface for no measurable gain. Text search
and the scalar filters are pushed into SQL; set intersections are done in Dart.

`_createV1` is **never edited in place**. New versions are reached only through
`_onUpgrade`, and a fresh install runs create-then-upgrade so the two paths
cannot drift. `test/database_test.dart` asserts that a v1 file upgraded to the
current version has exactly the same columns as a fresh install.

The snapshot is stored as one JSON column specifically so that adding a field to
`ContextSnapshot` — as a future camera or smart-glasses source would — needs no
migration. A corrupt blob costs one record its context rather than breaking the
history screen.

### How recommendation scoring works

`lib/domain/recommendation/recommendation_engine.dart` is deterministic, local,
Flutter-free and directly testable. It runs in three stages.

**1. Advisory.** If the context says the person appears occupied, is working, has
headphones on, is moving quickly, or the setting is isolated or unsafe, the
result is marked discouraged, carries the specific triggering conditions, and
returns **no openers at all** — only graceful exits. Warning and then handing
over an opener anyway would make the warning decorative. The library stays
browsable; this screen simply does not help.

**2. Hard exclusion.** A line is dropped, with a reason, if any of its
`avoidConditions` matches the context, if a required `UseCondition` is unmet, if
it needs a concrete cue nobody reported, or if it fails its own validation.
`genuineKnowledgeOfSubject` never auto-excludes — only you know whether you have
read the book — so it is surfaced on the card instead. An *empty* cue selection
means "unknown", not "absent", so skipping that section does not silently remove
every cue-specific line.

**3. Scoring.** Integer weights, all named constants at the top of the file:
location match and mismatch, cue matches (capped), activity, group size, noise
level, brevity in loud venues scaled by how loud, distance from the requested
directness, tone preference, a small favourite boost, and a bounded adjustment
from your own recorded history. A line offered in a recent round is demoted so
suggestions rotate, but it is still returned when it is the only option. Ties
break on line id, so ordering never wobbles between identical calls.

Every score carries a list of `ScoreFactor`s whose deltas sum exactly to the
score — a test asserts this — and the factors are **codes, not English prose**,
so explanations are translatable and assertable. `RecommendationResult.debugReport()`
prints the whole breakdown; the results screen has a bug-icon toggle that shows
it.

The three slots are filled safest → playful → more direct without reuse, then
backfilled if the library cannot supply a distinct line for each.

### How a future context provider supplies a ContextSnapshot

`lib/domain/context/context_provider.dart` defines:

```dart
abstract class ContextProvider {
  ContextSource get source;
  bool get isAvailable;
  String get id;
  Future<ContextSnapshot> captureContext();
}
```

Only `ManualContextProvider` is implemented. The situation builder screen already
routes through it rather than passing a snapshot to the engine directly, which is
what makes a later provider a drop-in swap: implement the interface, return a
`ContextSnapshot` with a different `source`, and neither the engine nor any
screen changes. `ContextSource` already deserializes `cameraScan`,
`smartGlasses` and `ambientAudio`, so records written by such a version stay
readable.

No sensor package is declared in `pubspec.yaml`. Adding an empty or broken camera
dependency now to "reserve" the feature would mean shipping a permission surface
for something that does not exist, so it is not there.

### Testing

```bash
flutter test
```

Covered: serialization round trips for all three models plus settings, and
forward compatibility with unknown enum names; database creation, the v1→v2
migration against a real file, create/upgrade parity, and foreign-key cascade;
CRUD, search, every filter and all four sort orders; the advisory for each of its
five conditions; hard exclusions; location, cue, group-size, noise and
directness matching; short-line preference in loud venues; favourite and history
adjustments; rotation; determinism and tie-breaking; import validation against a
list of deliberately malformed inputs; duplicate-id handling and re-keying;
schema-version migration and rejection of a newer schema; the starter library's
size, validity, uniqueness and coverage; and widget tests that start the app on
an empty database and on a seeded one, walk the full recommendation flow, record
an outcome and confirm it persists, and check that the advisory suppresses
openers.

`test/version_consistency_test.dart` checks that `version.txt`, `pubspec.yaml`,
`AppInfo.version`, `installer/opencue.iss` and `CHANGELOG.md` all agree.
`test/localization_test.dart` checks that both string tables have identical keys,
that every enum value and score-factor code has a label, and that placeholders
match between languages.

No lint is disabled to hide a problem. `analysis_options.yaml` turns `unused_import`,
`unused_local_variable` and `dead_code` into errors, and disables exactly two
stylistic rules, each with a written justification.

### Generated files

`lib/l10n/strings_en.dart`, `lib/l10n/strings_ja.dart`,
`lib/data/seed/starter_library.dart`, `assets/sample/starter_library.json` and
the icons are generated. Edit the generator in `tool/`, re-run it, and commit
both. CI regenerates and diffs, so hand-editing the output fails the build. See
`tool/README.md`.

### Versioning

`version.txt` is the single source of truth, currently `0.1.0`. It is restated in
`pubspec.yaml`, `lib/core/app_info.dart` and `installer/opencue.iss` because none
of those can read a Dart constant. `dart tool/check_version.dart` compares all
four and runs in CI before anything is built.

### Publisher and code signing

Two placeholders must be replaced before publishing:

- **Publisher name** — `PUBLISHER_PLACEHOLDER` in `lib/core/app_info.dart`
  (`AppInfo.publisher`), `installer/opencue.iss` (`MyAppPublisher`) and `LICENSE`.
  A test asserts the placeholder is still intact so it cannot be half-edited.
- **Repository URL** — `https://github.com/OWNER/opencue` in
  `lib/core/app_info.dart` and `installer/opencue.iss`.

Code signing is prepared but inactive. `installer/opencue.iss` has commented
`SignTool` and `SignedUninstaller` directives; with a certificate available,
configure a sign tool and uncomment both. Until then Windows SmartScreen will
warn on first run, which is expected for an unsigned installer.

### Known limitations

- **Windows only so far.** The domain and data layers carry no platform
  assumptions and the UI is responsive, but no Android build has been attempted
  and `sqflite_common_ffi` would be swapped for `sqflite` there.
- **No scan.** Manual context entry is the only input. This is a deliberate
  scope decision, not a stub.
- **Statistics are intentionally shy.** Proportions appear only above 8 recorded
  outcomes and per-line rankings only above 12, so early numbers are shown as
  counts. This makes the screen look sparse at first, which is the correct
  trade-off against quoting "100% positive" from one interaction.
- **Search is `LIKE`-based**, with no stemming, romaji matching or kana folding.
  Searching `かわいい` will not match `可愛い`.
- **Statistics are session-wide, not per-context.** The engine uses a line's
  overall record, not its record in this kind of venue.
- **Rotation is session-only.** Which lines were shown recently is not
  persisted, so restarting the app resets the rotation window.
- **The installer is unsigned**, as above.
- **One language pair.** The l10n structure supports adding languages by adding a
  table, but only English and Japanese exist.

### Licence

MIT. See `LICENSE`.
