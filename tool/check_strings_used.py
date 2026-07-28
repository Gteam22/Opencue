#!/usr/bin/env python3
"""Verify that every literal l10n key used in Dart source actually exists.

`AppLocalizations.t` falls back to the key itself when a lookup misses, which
is the right runtime behaviour but hides typos completely. This script closes
that gap by extracting every literal key passed to `t(...)` or `f(...)` and
checking it against the generated tables.

Run from the repository root:

    python3 tool/check_strings_used.py

Exits non-zero and lists the offenders if anything is missing. The CI workflow
runs this before `flutter test`.
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Keys passed as literals: strings.t('x'), strings.f('x', [...]), t('x').
CALL_RE = re.compile(r"\b[tf]\(\s*'([a-zA-Z0-9_.]+)'")

# Keys sitting in a const list of key names, as the privacy section uses.
LIST_RE = re.compile(r"'((?:about|advisory)\.[a-zA-Z0-9_]+)'")

# Direct table subscripts, which the widget tests use to assert on real labels:
# stringsEn['home.findLine']. A typo here fails at runtime on the null check.
TABLE_ACCESS_RE = re.compile(r"strings(?:En|Ja)\[\s*'([a-zA-Z0-9_.]+)'\s*\]")

TABLE_RE = re.compile(r"^\s*'([^']+)':", re.MULTILINE)

# Keys that are deliberately absent. The localization test asserts that an
# unknown key is echoed back rather than throwing, so it has to reference one.
ALLOWED_MISSING = {"no.such.key", "something.unmapped"}


def table_keys(path: pathlib.Path) -> set[str]:
    return set(TABLE_RE.findall(path.read_text(encoding="utf-8")))


def main() -> int:
    en = table_keys(ROOT / "lib/l10n/strings_en.dart")
    ja = table_keys(ROOT / "lib/l10n/strings_ja.dart")

    if en != ja:
        only_en = sorted(en - ja)
        only_ja = sorted(ja - en)
        print("FAIL: the English and Japanese tables have different keys.")
        for key in only_en:
            print(f"  missing from Japanese: {key}")
        for key in only_ja:
            print(f"  missing from English:  {key}")
        return 1

    missing: dict[str, list[str]] = {}
    checked = 0

    sources = sorted(ROOT.glob("lib/**/*.dart")) + sorted(
        ROOT.glob("test/**/*.dart")
    )
    for path in sources:
        if path.match("lib/l10n/*"):
            continue
        text = path.read_text(encoding="utf-8")
        used = (
            set(CALL_RE.findall(text))
            | set(LIST_RE.findall(text))
            | set(TABLE_ACCESS_RE.findall(text))
        )
        for key in sorted(used):
            # Dotted enum-derived keys are built at runtime and covered by the
            # generator's own completeness check, so only literals land here.
            checked += 1
            if key not in en and key not in ALLOWED_MISSING:
                missing.setdefault(str(path.relative_to(ROOT)), []).append(key)

    if missing:
        print("FAIL: keys used in Dart source but absent from the tables.")
        for file, keys in missing.items():
            print(f"  {file}")
            for key in keys:
                print(f"    {key}")
        return 1

    print(
        f"OK: {checked} literal key uses resolved against "
        f"{len(en)} keys in each of 2 languages."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
