# `tool/`

Generators and checkers. None of this ships in the application.

| Script | What it does |
| --- | --- |
| `build_seed.py` | Authors the starter library and emits `lib/data/seed/starter_library.dart` and `assets/sample/starter_library.json`. |
| `build_strings.py` | Emits `lib/l10n/strings_en.dart` and `lib/l10n/strings_ja.dart` from one source of truth. |
| `make_icon.py` | Draws the OpenCue mark and writes `assets/icons/opencue.ico` and the PNGs. |
| `check_version.dart` | Verifies the version agrees across four files. |
| `check_strings_used.py` | Verifies every l10n key referenced in Dart exists in both tables. |
| `check_dart_sanity.py` | Structural checks on the Dart sources. |
| `check_dart_symbols.py` | Resolves every project-internal import; reports unused and missing ones. |
| `check_lint_risks.py` | Approximates the lints this project escalates to errors. |

Run the generators from the repository root and commit their output. CI
regenerates and diffs, so editing a generated file by hand fails the build.

```bash
python3 tool/build_strings.py
python3 tool/build_seed.py
python3 tool/make_icon.py
```

## Why generate rather than hand-write

**The string tables** must have identical key sets in both languages, and every
enum value and every `ScoreFactorCode` must have a label. Maintaining that by
hand across two files means the failure mode is a raw dotted key appearing in the
UI. The generator holds both languages in one `add()` call per key, and refuses
to emit anything if a label is missing — so the error surfaces at generation
time, in a terminal, instead of in front of a user.

**The starter library** is 155 entries with about a dozen tag fields each. Every
tag has to be a real enum value; a typo would be silently dropped by
`enumSetFromJson`, and the line would quietly stop being suggested in the
situation it was written for. So `build_seed.py` parses
`lib/domain/enums/enums.dart` and validates every tag against the actual enums,
and also rejects duplicate ids and duplicate Japanese text.

**The icon** is drawn from the same geometry as `OpenCueMark` in
`lib/features/shared/widgets.dart`, so the in-app mark and the Windows icon
cannot drift. Generating it also keeps the shape reviewable in a diff, which an
opaque committed `.ico` would not be.

## `check_dart_sanity.py` and the missing toolchain

This script does string- and comment-aware delimiter balancing, and checks tabs,
trailing whitespace, 80 columns and a final newline. It is **not** a compiler and
does not replace `flutter analyze`; it exists because those checks are cheap and
catch the class of mistake that is easy to make in bulk.

Generated files are exempt from the column check only. `dart format` cannot split
a string literal, so a long translated sentence stays on one long line and is not
a formatting failure. Their structure is still checked.

## Why there are checkers at all

`analysis_options.yaml` turns `unused_import`, `unused_local_variable` and
`dead_code` into **errors**, so a single stale import fails the build rather than
producing a warning. `check_dart_symbols.py` resolves every import that points
inside the project, works out which top-level names each file declares, and then
checks that each internal import contributes at least one name the file actually
uses — and, in the other direction, that every capitalised project name a file
references is reachable through its own imports.

External imports (Flutter, sqflite, `dart:` libraries) are listed but not judged.
Resolving them properly would need their symbol tables, and guessing produces
false positives, which is worse than silence in a checker.

`check_lint_risks.py` approximates `prefer_final_locals`,
`always_declare_return_types` and `unawaited_futures`. It is a heuristic and says
so: it exits zero, because a finding is a prompt to look rather than a verdict.
Confirmed false positives are listed in `CONFIRMED_FALSE_POSITIVES` **with the
reason**, so a genuine new finding is not lost in noise. There is currently one
entry: sqflite's `Batch.insert` returns `void`, and the heuristic matches the
name against the repository's own `Future<void> insert`.

`flutter analyze` remains the authority for all of this.

## On the starter library's content

The source material was a large collection of Japanese opening lines with
situational notes. It was not adopted wholesale. Lines were **dropped rather than
tagged** when they were:

- **Backhanded.** "見た目より話しやすいですね" ("you're easier to talk to than you
  look") is an insult with a compliment's shape.
- **Presumptuous about the other person.** "たぶん自分がかわいいの分かってますよね"
  ("you probably know you're cute") tells someone what they think about
  themselves.
- **Built on isolating someone from their friends.** The engine has a
  `withOneFriend` category precisely so that the opposite approach — address both
  people — is the one that gets suggested.
- **Pressure-based**, including anything that treats a refusal as an obstacle to
  work around.

What remains is ordinary, respectful language: an observation about the shared
situation, or a specific and true compliment, with an easy way for the other
person to decline. Every line carries honest avoid conditions, because a line
tagged as suitable everywhere is a line the engine cannot reason about.

The four graceful exits the specification names are present, and exits are
tagged for every venue, so the app can always offer a way to leave well. That is
treated as a first-class feature rather than an afterthought: a test asserts that
an exit line is available at every single location.
