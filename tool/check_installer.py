#!/usr/bin/env python3
"""Structural checks on installer/opencue.iss.

Inno Setup is only ever compiled on Windows, which means a mistake in this file
survives every other check in the repository and only surfaces at the very last
step of CI, after a full Flutter build has already run. These checks are cheap
and catch the classes of error that have actually happened.

The main one: inside the [Code] section, Inno Setup's Pascal treats `{` as a
comment opener and the *next* `}` as its closer. A braced comment that mentions
a constant like `{app}` therefore ends halfway through the sentence, and the
remainder of the prose is parsed as code. Use `//` comments there instead.

Run:  python3 tool/check_installer.py
"""

from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ISS = ROOT / "installer" / "opencue.iss"

# Directives the installer must keep, with why they matter.
REQUIRED_SETUP = {
    "AppId": "a stable GUID; changing it breaks in-place upgrades",
    "AppName": "shown throughout the wizard",
    "AppVersion": "checked against version.txt by check_version.dart",
    "AppPublisher": "shown in the wizard and in Add/Remove Programs",
    "PrivilegesRequired": "must stay 'lowest' for a per-user install",
    "OutputBaseFilename": "must produce OpenCue-Setup.exe",
    "SetupIconFile": "the installer's own icon",
}


def sections(text: str) -> dict[str, list[tuple[int, str]]]:
    """Splits the script into sections, keeping 1-based line numbers."""
    found: dict[str, list[tuple[int, str]]] = {}
    current = ""
    for number, line in enumerate(text.split("\n"), start=1):
        header = re.match(r"^\s*\[(\w+)\]\s*$", line)
        if header:
            current = header.group(1).lower()
            found.setdefault(current, [])
            continue
        if current:
            found[current].append((number, line))
    return found


def check_code_comments(lines: list[tuple[int, str]]) -> list[str]:
    """Flags braced comments in the [Code] section."""
    problems = []
    for number, line in lines:
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        # Strip single-quoted Pascal strings; braces inside them are data,
        # e.g. ExpandConstant('{app}\\opencue.db').
        without_strings = re.sub(r"'[^']*'", "''", line)
        if "{" not in without_strings:
            continue
        opener = without_strings.index("{")
        closer = without_strings.find("}", opener)
        if closer != -1:
            problems.append(
                f"line {number}: braced comment closes early at the '}}' in "
                f"this line - use a // comment instead"
            )
        else:
            problems.append(
                f"line {number}: '{{' opens a Pascal comment in [Code]; the "
                f"next '}}' anywhere below will close it - use // instead"
            )
    return problems


def main() -> int:
    if not ISS.exists():
        print(f"FAIL: {ISS.relative_to(ROOT)} is missing.")
        return 1

    text = ISS.read_text(encoding="utf-8")
    parts = sections(text)
    problems: list[str] = []

    if "code" in parts:
        problems += check_code_comments(parts["code"])
    else:
        problems.append("no [Code] section found")

    setup_lines = parts.get("setup", [])
    setup_text = "\n".join(line for _, line in setup_lines)
    for directive, why in REQUIRED_SETUP.items():
        if not re.search(rf"^\s*{directive}\s*=", setup_text, re.MULTILINE):
            problems.append(f"[Setup] is missing {directive} ({why})")

    # The output name is what the workflow and the README both promise.
    match = re.search(
        r"^\s*OutputBaseFilename\s*=\s*(\S+)", setup_text, re.MULTILINE
    )
    if match and match.group(1).strip() != "OpenCue-Setup":
        problems.append(
            f"OutputBaseFilename is '{match.group(1)}', but the workflow and "
            f"README expect 'OpenCue-Setup'"
        )

    # Per-user install: the whole point of not needing administrator rights.
    if not re.search(
        r"^\s*PrivilegesRequired\s*=\s*lowest", setup_text, re.MULTILINE
    ):
        problems.append(
            "PrivilegesRequired must be 'lowest' so the installer does not "
            "demand administrator rights"
        )

    # The database must never be installed into, or deleted from, {app}.
    if re.search(r"^\s*Source:.*opencue\.db", text, re.MULTILINE):
        problems.append(
            "the database must not be shipped as an installed file; it "
            "belongs in the user's AppData"
        )

    # BuildDir must remain overridable from the command line. An `#ifndef`
    # guarded default is correct and intended (it makes a bare local `iscc`
    # run work); an unconditional `#define` would silently ignore whatever
    # directory the workflow located and is the thing worth catching.
    for number, line in enumerate(text.split("\n"), start=1):
        if not re.match(r"^\s*#define\s+BuildDir\b", line):
            continue
        preceding = "\n".join(text.split("\n")[: number - 1])
        # Look for an unclosed #ifndef/#if above this line.
        opens = len(re.findall(r"^\s*#if(?:n?def)?\b", preceding, re.MULTILINE))
        closes = len(re.findall(r"^\s*#endif\b", preceding, re.MULTILINE))
        if opens <= closes:
            problems.append(
                f"line {number}: BuildDir is defined unconditionally; it must "
                f"stay overridable via /DBuildDir= from the workflow"
            )

    if problems:
        print("FAIL: installer/opencue.iss")
        for problem in problems:
            print(f"  {problem}")
        return 1

    print(
        f"OK: installer/opencue.iss - {len(parts)} sections, "
        f"all required [Setup] directives present, no braced comments in "
        f"[Code]."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
