#!/usr/bin/env python3
"""Resolves project-internal imports and reports unused or missing ones.

`analysis_options.yaml` escalates `unused_import` to an error, so a single stale
import fails the build. This script resolves every import that points inside the
project, works out which top-level names each file declares, and then checks two
things per file:

  1. Every internal import contributes at least one name the file actually uses.
  2. Every capitalised name the file uses that is declared somewhere in the
     project is reachable through this file's own imports.

Imports of external packages (Flutter, sqflite, dart: libraries) are listed but
not judged: resolving them would need their symbol tables, and guessing produces
false positives. Those are checked by hand and, ultimately, by `flutter analyze`.

Run:  python3 tool/check_dart_symbols.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PACKAGE = "opencue"


def read_source(path: pathlib.Path) -> str:
    """Read Dart, collapsing generated embedded JSON to its declaration.

    Walking hundreds of thousands of string characters through the small
    hand-written lexer is both pointless and disproportionately slow; generated
    seed files contain no imports or executable references inside that JSON.
    """
    raw = path.read_text(encoding="utf-8")
    if raw.startswith("// GENERATED FILE."):
        match = re.search(r"const\s+String\s+(\w+)\s*=", raw)
        if match:
            return f"const String {match.group(1)} = '';\n"
    return raw

IMPORT_RE = re.compile(
    r"^\s*(import|export)\s+'([^']+)'((?:\s+(?:as|show|hide)\s+[^;]*)?)\s*;",
    re.MULTILINE,
)

# Top-level declarations. Only what can be referenced from another file.
DECL_PATTERNS = [
    re.compile(r"^(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+)*"
               r"class\s+([A-Za-z_$][\w$]*)", re.MULTILINE),
    re.compile(r"^enum\s+([A-Za-z_$][\w$]*)", re.MULTILINE),
    re.compile(r"^mixin\s+([A-Za-z_$][\w$]*)", re.MULTILINE),
    re.compile(r"^extension\s+([A-Za-z_$][\w$]*)", re.MULTILINE),
    re.compile(r"^typedef\s+([A-Za-z_$][\w$]*)", re.MULTILINE),
    # Top-level variables and constants: `const int kMinDirectness = 1;`,
    # `final DateTime testTime = ...`, `const Map<String, String> stringsEn =`.
    re.compile(r"^(?:const|final)\s+[\w<>,?\s$]*?([A-Za-z_$][\w$]*)\s*=",
               re.MULTILINE),
    # Top-level functions, including those returning a generic or record type.
    re.compile(r"^(?:[\w<>,?\s$().]+?\s+)([a-z_$][\w$]*)\s*(?:<[^>]*>)?\s*\(",
               re.MULTILINE),
]

# Dart keywords that the loose function pattern can otherwise pick up.
NOT_DECLARATIONS = {
    "if", "for", "while", "switch", "return", "assert", "await", "else",
    "catch", "do", "new", "throw", "super", "this", "void", "yield", "import",
    "export", "part", "library", "typedef", "class", "enum", "extension",
    "mixin", "const", "final", "var", "get", "set", "operator", "factory",
    "external", "static", "abstract", "covariant", "late", "required",
    "expect", "test", "group", "setUp", "setUpAll", "tearDown", "addTearDown",
    "testWidgets", "main", "print", "expectLater", "throwsA", "isA",
}


def strip_noise(text: str) -> str:
    """Removes comments and string bodies so identifiers inside them are not
    mistaken for code references."""
    out = []
    i = 0
    n = len(text)
    while i < n:
        ch = text[i]
        if ch == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if ch == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            depth = 1
            while i < n and depth:
                if text.startswith("/*", i):
                    depth += 1
                    i += 1
                elif text.startswith("*/", i):
                    depth -= 1
                    i += 1
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            continue
        if ch in "'\"" or (ch == "r" and i + 1 < n and text[i + 1] in "'\""):
            raw = ch == "r"
            if raw:
                i += 1
            quote = text[i]
            triple = text.startswith(quote * 3, i)
            term = quote * 3 if triple else quote
            # The delimiters are kept, and only the contents blanked, so that a
            # caller can still tell "a string literal was here". check_lint_risks
            # relies on this to distinguish `group('x', () {}` from a real
            # parameter list.
            out.append(term)
            i += len(term)
            while i < n:
                if not raw and text[i] == "\\":
                    i += 2
                    continue
                if text.startswith(term, i):
                    out.append(term)
                    i += len(term)
                    break
                # Interpolated expressions are real code and must be kept.
                if not raw and text.startswith("${", i):
                    depth = 0
                    start = i + 1
                    while i < n:
                        if text[i] == "{":
                            depth += 1
                        elif text[i] == "}":
                            depth -= 1
                            if depth == 0:
                                i += 1
                                break
                        i += 1
                    out.append(text[start:i])
                    continue
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            continue
        out.append(ch)
        i += 1
    return "".join(out)


def declarations(code: str) -> set[str]:
    found: set[str] = set()
    for pattern in DECL_PATTERNS:
        for name in pattern.findall(code):
            if name not in NOT_DECLARATIONS and not name.startswith("_"):
                found.add(name)
    return found


def resolve(uri: str, source: pathlib.Path) -> pathlib.Path | None:
    """Maps an import URI to a file inside the project, or None if external."""
    if uri.startswith(f"package:{PACKAGE}/"):
        return ROOT / "lib" / uri[len(f"package:{PACKAGE}/"):]
    if uri.startswith("package:") or uri.startswith("dart:"):
        return None
    return (source.parent / uri).resolve()


def used_names(code: str) -> set[str]:
    """Identifiers the file references, excluding member names after a dot."""
    names: set[str] = set()
    for match in re.finditer(r"(\.?)\b([A-Za-z_$][\w$]*)", code):
        if match.group(1) == ".":
            continue
        names.add(match.group(2))
    return names


# Packages that re-export another package wholesale. Importing both, without a
# prefix on one of them, is an `unnecessary_import` — which this project treats
# as a hard error, so it fails the build at `flutter analyze`.
#
# External imports are otherwise not judged here (resolving them properly would
# need their symbol tables). This is a hand-maintained list of the specific
# pairs this repository actually uses, added after one of them cost a full CI
# run: sqflite_ffi re-exports sqlite_api, and importing both looked perfectly
# reasonable.
RE_EXPORTS = {
    "package:sqflite_common_ffi/sqflite_ffi.dart": {
        "package:sqflite_common/sqlite_api.dart",
    },
    "package:sqflite/sqflite.dart": {
        "package:sqflite_common/sqlite_api.dart",
    },
}


def redundant_external_imports(directives) -> list[str]:
    """Flags an unprefixed import already covered by another import."""
    # (uri -> whether it was imported with an `as` prefix)
    plain = {
        uri
        for kind, uri, suffix in directives
        if kind == "import" and " as " not in suffix
    }
    problems = []
    for superset, covered in RE_EXPORTS.items():
        if superset not in plain:
            continue
        for subset in covered & plain:
            problems.append(
                f"redundant import '{subset}': "
                f"'{superset}' already re-exports it (unnecessary_import)"
            )
    return problems


def main() -> int:
    sources = sorted(ROOT.glob("lib/**/*.dart")) + sorted(
        ROOT.glob("test/**/*.dart")
    ) + sorted(ROOT.glob("tool/*.dart"))

    decls: dict[pathlib.Path, set[str]] = {}
    for path in sources:
        raw = read_source(path)
        decls[path] = declarations(strip_noise(IMPORT_RE.sub("", raw)))

    # Every name declared anywhere, so a reference can be attributed to a file.
    owner: dict[str, list[pathlib.Path]] = {}
    for path, names in decls.items():
        for name in names:
            owner.setdefault(name, []).append(path)

    problems: dict[str, list[str]] = {}
    external_by_file: dict[str, set[str]] = {}
    checked_imports = 0

    for path in sources:
        rel = str(path.relative_to(ROOT))
        raw = read_source(path)
        # Imports are read from the raw text: strip_noise blanks string bodies,
        # and an import URI is a string literal.
        directives = IMPORT_RE.findall(raw)
        code = strip_noise(IMPORT_RE.sub("", raw))
        names = used_names(code)
        issues: list[str] = []
        reachable = set(decls[path])
        external: set[str] = set()

        for kind, uri, _suffix in directives:
            target = resolve(uri, path)
            if target is None:
                external.add(uri)
                continue
            checked_imports += 1
            if not target.exists():
                issues.append(f"{kind} '{uri}' does not exist")
                continue
            provided = decls.get(target, set())
            reachable |= provided
            if kind == "import" and not (provided & names):
                issues.append(
                    f"unused import '{uri}' "
                    f"(nothing from it is referenced)"
                )

        external_by_file[rel] = external
        issues += redundant_external_imports(directives)

        # A capitalised name declared in this project but not reachable here is
        # a missing import. Names owned by nothing are assumed external.
        for name in sorted(names):
            if not name[:1].isupper():
                continue
            if name in reachable or name not in owner:
                continue
            homes = ", ".join(
                str(p.relative_to(ROOT)) for p in owner[name]
            )
            issues.append(f"'{name}' is not imported (declared in {homes})")

        if issues:
            problems[rel] = issues

    if problems:
        print("FAIL: internal import problems.\n")
        for file, issues in problems.items():
            print(f"  {file}")
            for issue in issues:
                print(f"    {issue}")
        return 1

    print(
        f"OK: {checked_imports} internal imports across {len(sources)} files "
        f"all resolve and are used."
    )
    print("\nExternal imports (not verified here, checked by flutter analyze):")
    tally: dict[str, int] = {}
    for uris in external_by_file.values():
        for uri in uris:
            tally[uri] = tally.get(uri, 0) + 1
    for uri, count in sorted(tally.items(), key=lambda kv: -kv[1]):
        print(f"  {count:3d}  {uri}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
