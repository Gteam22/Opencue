#!/usr/bin/env python3
"""Approximates the lints this project has turned on or escalated to errors.

`analysis_options.yaml` makes `unused_import`, `unused_local_variable` and
`dead_code` errors, and enables `prefer_final_locals`, `always_declare_return_types`
and `unawaited_futures`. Those are exactly the rules most likely to fail a first
CI run on freshly written code, and each is approximable by inspection.

This is a heuristic, deliberately biased towards reporting something a human then
confirms. `flutter analyze` is the authority; this exists because it cannot be
run in this environment.

Run:  python3 tool/check_lint_risks.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Findings confirmed to be false positives, with the reason. The heuristic
# matches a called name against Future-returning declarations anywhere in the
# same file, so a same-named method on a different receiver looks like a hit.
CONFIRMED_FALSE_POSITIVES = {
    (
        "lib/data/repositories/sqlite_repositories.dart",
        "insert",
    ): "sqflite Batch.insert returns void; it queues the statement, and the "
       "batch is awaited by commit() on the next line.",
}

sys.path.insert(0, str(ROOT / "tool"))
from check_dart_symbols import (  # noqa: E402
    IMPORT_RE,
    NOT_DECLARATIONS,
    strip_noise,
)

# `var x = ...` outside a for-header. Reported only when x is never assigned
# again in the enclosing file, which is a safe over-approximation of scope.
VAR_RE = re.compile(r"^(\s*)var\s+([A-Za-z_$][\w$]*)\s*=", re.MULTILINE)

# A member declaration with no return type: `foo() {` or `foo() =>` at class
# indentation, excluding constructors, getters, setters and known keywords.
#
# The negative lookahead on the first character inside the parentheses is what
# separates a declaration from a call: `group('schema', () {` opens with a
# string and `setUpAll(() {` with a paren, whereas a real parameter list starts
# with a type, a modifier, or nothing at all.
MISSING_RETURN_RE = re.compile(
    r"^  ([a-z_$][\w$]*)\s*(?:<[^>\n]*>)?\s*"
    r"\((?!['\"(])[^;{=]*\)\s*(?:async\s*)?[{=]",
    re.MULTILINE,
)


def local_var_risks(code: str) -> list[str]:
    findings = []
    for match in VAR_RE.finditer(code):
        name = match.group(2)
        # Count assignments after the declaration: `name =`, `name +=`, `name++`.
        rest = code[match.end():]
        reassigned = re.search(
            rf"\b{re.escape(name)}\s*(?:=[^=]|\+=|-=|\*=|/=|\+\+|--)", rest
        )
        if not reassigned:
            line = code[: match.start()].count("\n") + 1
            findings.append(
                f"line {line}: 'var {name}' is never reassigned "
                f"(prefer_final_locals)"
            )
    return findings


def missing_return_types(code: str) -> list[str]:
    findings = []
    for match in MISSING_RETURN_RE.finditer(code):
        name = match.group(1)
        if name in {"if", "for", "while", "switch", "catch", "return", "assert"}:
            continue
        line = code[: match.start()].count("\n") + 1
        findings.append(
            f"line {line}: '{name}(...)' declares no return type "
            f"(always_declare_return_types)"
        )
    return findings


def async_line_map(code: str) -> set[int]:
    """Line numbers that sit inside the body of an `async` function.

    `unawaited_futures` only fires inside an async body, so without this the
    check reports every fire-and-forget call in a synchronous callback, which is
    both legal and intentional. Brace depths are tracked so a nested synchronous
    closure inside an async method is not counted, and vice versa.
    """
    inside: set[int] = set()
    depth = 0
    line = 1
    # Depths at which an async body was opened.
    async_depths: list[int] = []
    i = 0
    n = len(code)
    while i < n:
        ch = code[i]
        if ch == "\n":
            line += 1
            if async_depths:
                inside.add(line)
        elif ch == "{":
            # Look back over the current line for an `async` marker.
            start = code.rfind("\n", 0, i) + 1
            if re.search(r"\basync\b\s*\*?\s*$", code[start:i]):
                async_depths.append(depth)
            depth += 1
        elif ch == "}":
            depth -= 1
            while async_depths and async_depths[-1] >= depth:
                async_depths.pop()
        i += 1
    return inside


def unawaited_risks(code: str) -> list[str]:
    """Bare statement calls, inside an async body, to a Future-returning member."""
    async_methods = set(
        re.findall(r"(?:Future<[^>]*>|Future)\s+([A-Za-z_$][\w$]*)\s*\(", code)
    )
    if not async_methods:
        return []
    in_async = async_line_map(code)
    findings = []
    for number, raw_line in enumerate(code.split("\n"), start=1):
        if number not in in_async:
            continue
        stripped = raw_line.strip()
        if stripped.startswith(("await ", "return ", "unawaited(")):
            continue
        match = re.match(r"^([A-Za-z_$][\w$.]*)\s*\(", stripped)
        if not match or not stripped.endswith(";"):
            continue
        target = match.group(1).split(".")[-1]
        if target in async_methods:
            findings.append(
                (
                    target,
                    f"line {number}: '{target}(...)' called as a bare statement "
                    f"inside an async body (unawaited_futures)",
                )
            )
    return findings


def local_function_order_risks(code: str) -> list[str]:
    """Local functions declared inside a block, called before their own
    declaration line.

    Unlike top-level functions, Dart's local function declarations do not
    hoist across each other: a local function can only call a sibling local
    function that was declared textually earlier in the same block. This is
    easy to get backwards when refactoring test helpers, and `flutter analyze`
    is the only thing that has ever actually caught it here.
    """
    # `ReturnType name(` or `ReturnType name<T>(` at 2-space (block-local)
    # indentation, immediately followed by a parameter list and `{` or `=>` —
    # distinguishes a declaration from a call by requiring a type-shaped token
    # before the name.
    decl_re = re.compile(
        r"^  (?:[\w<>,?\[\]]+\s+)+([a-zA-Z_$][\w$]*)\s*(?:<[^>\n]*>)?\s*\(",
        re.MULTILINE,
    )
    declared_at: dict[str, int] = {}
    for match in decl_re.finditer(code):
        name = match.group(1)
        if name in NOT_DECLARATIONS:
            continue
        line = code[: match.start()].count("\n") + 1
        # First declaration wins; a name can only be declared once per block
        # in valid Dart, so this is safe even though the regex is approximate.
        declared_at.setdefault(name, line)

    if not declared_at:
        return []

    findings = []
    call_re = re.compile(r"(?<![\w$.])([a-zA-Z_$][\w$]*)\s*\(")
    for match in call_re.finditer(code):
        name = match.group(1)
        if name not in declared_at:
            continue
        line = code[: match.start()].count("\n") + 1
        if line == declared_at[name]:
            continue  # this is the declaration itself
        if line < declared_at[name]:
            findings.append(
                f"line {line}: '{name}(...)' called before its own "
                f"declaration on line {declared_at[name]} "
                f"(referenced_before_declaration)"
            )
    return findings


def main() -> int:
    sources = sorted(ROOT.glob("lib/**/*.dart")) + sorted(
        ROOT.glob("test/**/*.dart")
    ) + sorted(ROOT.glob("tool/*.dart"))

    total = 0
    waived: list[str] = []
    for path in sources:
        raw = path.read_text(encoding="utf-8")
        code = strip_noise(IMPORT_RE.sub("", raw))
        # as_posix(): CONFIRMED_FALSE_POSITIVES is keyed with forward slashes,
        # and relative_to() otherwise returns backslashes on Windows, which
        # would silently stop the waiver below from matching.
        rel = path.relative_to(ROOT).as_posix()
        findings = local_var_risks(code) + missing_return_types(code)
        if str(path.parent.relative_to(ROOT)).startswith("test"):
            # Scoped to test files on purpose: this pattern only matters for
            # local functions declared inside a `main() { ... }` block, which
            # is where ad-hoc test helpers like `pumpApp`/`settle` live.
            # lib/ code declares widgets and methods as top-level classes and
            # class members, which are resolved by name regardless of
            # textual order — the same regex applied there produced dozens of
            # false positives on ordinary, correct widget code.
            findings += local_function_order_risks(code)
        for target, message in unawaited_risks(code):
            reason = CONFIRMED_FALSE_POSITIVES.get((rel, target))
            if reason is None:
                findings.append(message)
            else:
                waived.append(f"{rel}: {target} - {reason}")
        if findings:
            total += len(findings)
            print(f"{rel}")
            for finding in findings:
                print(f"  {finding}")

    if waived:
        print("Waived (confirmed false positives):")
        for entry in waived:
            print(f"  {entry}")
        print()
    print(f"{total} item(s) to review by hand.")
    # Advisory only: these are heuristics, so a finding is a prompt to look, not
    # a build failure. Exit code stays zero on purpose.
    return 0


if __name__ == "__main__":
    sys.exit(main())
