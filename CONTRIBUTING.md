# Contributing to OpenCue

## Before you open a pull request

```bash
flutter pub get
dart format .
flutter analyze
flutter test
dart tool/check_version.dart
python3 tool/check_strings_used.py
python3 tool/check_dart_sanity.py
python3 tool/check_dart_symbols.py
python3 tool/check_lint_risks.py
python3 tool/check_installer.py
```

CI runs all of these plus the Windows release build and the installer
compilation. If a check is inconvenient, fix the cause rather than the check.

## Architecture rules

These are enforced by review, and breaking them is the fastest way to make the
codebase hard to move to Android later.

1. **`lib/domain/` must not import Flutter.** Not `material.dart`, not
   `widgets.dart`, not `foundation.dart`. If something in the domain layer seems
   to need a `BuildContext`, it belongs in `features/`.
2. **The recommendation engine touches no storage and no I/O.** It takes a
   context, a library and preferences, and returns a result. That is why it can
   be tested exhaustively without a database.
3. **Screens talk to repositories through the interfaces in
   `lib/domain/repositories/`**, never to `sqflite` directly.
4. **`lib/installer/` does not exist and should not.** The Inno Setup script
   knows about the app; the app knows nothing about how it was installed.
5. **Anything user-visible goes through `AppLocalizations`.** The data and domain
   layers return *keys* (`'import.error.notJson:...'`), never English sentences.

## Adding a line to the starter library

Edit `tool/build_seed.py`, then:

```bash
python3 tool/build_seed.py
```

The generator validates every tag against the real enums in
`lib/domain/enums/enums.dart`, rejects duplicate ids and duplicate Japanese text,
and requires an English meaning. Commit both the generator change and the two
generated files.

**On the lines themselves.** The starter library is ordinary, respectful
language. A line does not go in if it is manipulative, insulting, sexual,
coercive, pressure-based, deceptive, or presumes something about the other person
that you could not know. Backhanded compliments ("you're easier to talk to than
you look"), lines that presume interest, and lines that work by separating
someone from their friends were **dropped from the source material rather than
tagged**, and they should stay out. When in doubt, the test is whether the line
would be fine if the other person could read this repository.

Every line needs its avoid conditions filled in honestly. A line tagged as
suitable everywhere is a line the engine cannot reason about.

## Adding a string

Edit `tool/build_strings.py` — both languages, in one call to `add()` — then:

```bash
python3 tool/build_strings.py
```

Generation fails if any enum value or `ScoreFactorCode` lacks a label, and
`tool/check_strings_used.py` fails if a widget asks for a key that does not
exist. Do not edit `lib/l10n/strings_*.dart` by hand; CI regenerates and diffs.

## Adding an enum value

1. Add it to `lib/domain/enums/enums.dart`.
2. Add its label in `tool/build_strings.py` and re-run the generator; it will
   tell you if you forgot.
3. Consider whether the engine should score it. A new `LocationTag` needs no
   engine change; a new `AvoidCondition` almost certainly does.

Never renumber or rename an existing value. `Enum.name` is the stable identifier
in both the database and the JSON schema, so a rename silently drops that tag
from every existing row and every existing backup.

## Changing the database schema

1. Raise `AppInfo.databaseVersion`.
2. Add a `_migrateVNToVN1` method and call it from `_onUpgrade`.
3. **Do not edit `_createV1`.** A fresh install runs create-then-upgrade, so the
   create path and the upgrade path stay identical by construction, and
   `test/database_test.dart` asserts it.
4. Add a migration test that writes a row at the old version and reads it back
   through the current model.

## Changing the JSON transfer schema

1. Raise `AppInfo.transferSchemaVersion`.
2. Add a `_normaliseVersionN` step so older files still import.
3. Document the change in the `TransferService` class comment, which is the
   schema's reference documentation.
4. Add a test that a file at the previous version still imports correctly.

Importing must never throw. `TransferService.parse` returns a result; every
failure path is a message key.

## Things that need more than a passing thought

- **The advisory.** If you are changing when it fires or what it suppresses, say
  why in the PR. It withholds openers entirely on purpose.
- **Statistics thresholds.** `minimumForRates` and `minimumForLineRanking` exist
  so the app does not quote a percentage from three data points.
- **Anything touching the camera, microphone, network, or analytics.** There is
  none of any of these, the About screen states so as fact, and the claim should
  stay verifiable from `pubspec.yaml`.

## Commit and PR style

- Present tense, describing the change: "Add kana folding to library search".
- One concern per PR where you can manage it.
- If a test would have caught the bug you are fixing, add it in the same PR.
