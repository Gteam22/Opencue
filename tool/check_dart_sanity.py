#!/usr/bin/env python3
"""Cheap structural checks on the Dart sources.

This is not a compiler and does not pretend to be one. It catches the class of
mistake that is easy to make in bulk and tedious to find by eye: unbalanced
delimiters, stray tabs, trailing whitespace, lines past 80 columns, and files
that do not end in a newline. `flutter analyze` remains the real gate; this just
means the obvious problems are found before the toolchain is available.

Run:  python3 tool/check_dart_sanity.py
"""

from __future__ import annotations

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LIMIT = 80

# Generated files hold long string literals. `dart format` cannot split a
# string, so it leaves these lines alone and they are not a formatting failure;
# the column check would only produce noise. Their structure is still checked.
GENERATED = {
    "lib/data/seed/starter_library.dart",
    "lib/l10n/strings_en.dart",
    "lib/l10n/strings_ja.dart",
}

OPEN = {"(": ")", "[": "]", "{": "}"}
CLOSE = {v: k for k, v in OPEN.items()}


def scan(text: str) -> list[str]:
    """Walks the file tracking strings, comments and delimiter nesting."""
    problems: list[str] = []
    stack: list[tuple[str, int]] = []
    line = 1
    i = 0
    n = len(text)

    while i < n:
        ch = text[i]

        if ch == "\n":
            line += 1
            i += 1
            continue

        # Comments.
        if ch == "/" and i + 1 < n:
            if text[i + 1] == "/":
                while i < n and text[i] != "\n":
                    i += 1
                continue
            if text[i + 1] == "*":
                i += 2
                depth = 1
                while i < n and depth:
                    if text[i] == "\n":
                        line += 1
                    elif text.startswith("/*", i):
                        depth += 1
                        i += 1
                    elif text.startswith("*/", i):
                        depth -= 1
                        i += 1
                    i += 1
                continue

        # Strings, including raw and triple-quoted forms.
        if ch in "'\"" or (ch == "r" and i + 1 < n and text[i + 1] in "'\""):
            raw = ch == "r"
            if raw:
                i += 1
            quote = text[i]
            triple = text.startswith(quote * 3, i)
            terminator = quote * 3 if triple else quote
            i += len(terminator)
            while i < n:
                if text[i] == "\n":
                    line += 1
                    if not triple:
                        # Dart forbids a newline inside a single-quoted string,
                        # so this means the quote was never closed.
                        problems.append(f"line {line}: unterminated string")
                        break
                    i += 1
                    continue
                if not raw and text[i] == "\\":
                    i += 2
                    continue
                if text.startswith(terminator, i):
                    i += len(terminator)
                    break
                # Interpolation is skipped wholesale: the braces inside it are
                # balanced by definition and tracking them adds no value.
                if not raw and text.startswith("${", i):
                    depth = 0
                    i += 1
                    while i < n:
                        if text[i] == "{":
                            depth += 1
                        elif text[i] == "}":
                            depth -= 1
                            if depth == 0:
                                i += 1
                                break
                        elif text[i] == "\n":
                            line += 1
                        i += 1
                    continue
                i += 1
            continue

        if ch in OPEN:
            stack.append((ch, line))
        elif ch in CLOSE:
            if not stack:
                problems.append(f"line {line}: stray '{ch}'")
            else:
                opener, opened_at = stack.pop()
                if OPEN[opener] != ch:
                    problems.append(
                        f"line {line}: '{ch}' closes '{opener}' "
                        f"opened on line {opened_at}"
                    )
        i += 1

    for opener, opened_at in stack:
        problems.append(f"line {opened_at}: '{opener}' never closed")

    return problems


def main() -> int:
    failures = 0
    files = 0

    for path in sorted(ROOT.glob("**/*.dart")):
        if any(part in {"build", ".dart_tool"} for part in path.parts):
            continue
        files += 1
        rel = path.relative_to(ROOT)
        text = path.read_text(encoding="utf-8")
        problems = scan(text)

        if not text.endswith("\n"):
            problems.append("file does not end with a newline")

        for number, raw_line in enumerate(text.split("\n"), start=1):
            if "\t" in raw_line:
                problems.append(f"line {number}: tab character")
            if raw_line != raw_line.rstrip():
                problems.append(f"line {number}: trailing whitespace")
            # Japanese text is counted as one column per character here, which
            # matches how dart format measures it.
            if len(raw_line) > LIMIT and str(rel) not in GENERATED:
                problems.append(
                    f"line {number}: {len(raw_line)} columns (limit {LIMIT})"
                )

        if problems:
            failures += 1
            print(f"{rel}")
            for problem in problems[:20]:
                print(f"  {problem}")
            if len(problems) > 20:
                print(f"  ... and {len(problems) - 20} more")

    print(f"\nChecked {files} Dart files, {failures} with problems.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
