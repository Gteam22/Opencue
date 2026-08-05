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


def check_directive_order(text: str) -> list[str]:
    """Flags a `library;` directive that does not come first.

    Dart requires the library directive to precede every other directive.
    Placing it after the imports - which reads naturally, since the file's
    doc comment usually sits above the code rather than above the imports -
    is a hard compile error, not a style nit, and it takes down every test
    that transitively imports the file. It cost a whole CI run once.

    Only unindented directives at the start of a line are considered, so the
    word "library" inside a comment or a string is ignored.
    """
    problems: list[str] = []
    seen_directive: str | None = None
    seen_at = 0
    in_block_comment = False

    for number, raw_line in enumerate(text.split("\n"), start=1):
        line = raw_line.strip()

        if in_block_comment:
            if "*/" in line:
                in_block_comment = False
            continue
        if line.startswith("/*"):
            if "*/" not in line:
                in_block_comment = True
            continue
        if not line or line.startswith("//"):
            continue

        if line.startswith("library") and (
            line == "library;" or line.startswith("library ")
        ):
            if seen_directive is not None:
                problems.append(
                    f"line {number}: the library directive must come before "
                    f"all other directives, but '{seen_directive}' appears "
                    f"at line {seen_at}"
                )
            return problems

        for keyword in ("import ", "export ", "part "):
            if line.startswith(keyword):
                if seen_directive is None:
                    seen_directive = keyword.strip()
                    seen_at = number
                break
        else:
            # The first non-directive, non-comment line: any library directive
            # below this point is inside the body and not our concern.
            if seen_directive is not None or not line.startswith("@"):
                return problems

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
        problems.extend(check_directive_order(text))

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
