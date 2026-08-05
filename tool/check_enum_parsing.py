#!/usr/bin/env python3
"""Guards the enum parser the code generators depend on.

Both generators read Dart enums by splitting the enum body on commas and
keeping the bare words. That is only correct if comments are removed first.

The bug this exists to prevent: a doc comment containing a comma - "The scan
could see the place, and no person was in it." - splits mid-sentence, gluing
the identifier that follows onto comment text, where the bare-word filter
discards it. `GroupSize` lost four of its six values that way. Every seeded
line tagged `alone` or `withOneFriend` then failed validation,
`build_seed.py` exited non-zero, and CI stopped before building anything - so
no installer was produced. A semicolon inside a doc comment truncates the body
the same way, which is why comments must be stripped *before* the split on
';', not after.

The failure mode was nasty because the generator did not report an unknown
enum value. It reported a genuinely valid tag as invalid, pointing the blame
at the seed data rather than at the parser.

Checks:
  1. Each generator strips comments before splitting.
  2. Every enum parses to a non-empty list of valid identifiers.
  3. Reports how many values naive parsing would drop, so the value of the
     fix stays visible instead of becoming invisible once it works.
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SOURCES = [
    'lib/domain/enums/enums.dart',
    'lib/domain/scan/venue_category.dart',
    'lib/domain/recommendation/recommendation_models.dart',
    'lib/domain/context/radial_geometry.dart',
    'lib/domain/context/context_draft.dart',
    'lib/domain/models/context_snapshot.dart',
]

GENERATORS = ['tool/build_seed.py', 'tool/build_strings.py']


def strip_dart_comments(text):
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.S)
    return re.sub(r'//[^\n]*', '', text)


def parse(body, strip):
    if strip:
        body = strip_dart_comments(body)
    body = body.split(';')[0]
    return [v for v in (x.strip() for x in body.split(','))
            if re.fullmatch(r'[A-Za-z_]\w*', v)]


def check_generators():
    """Each generator must strip comments before it splits on ';'."""
    problems = []
    for relative in GENERATORS:
        path = os.path.join(ROOT, relative)
        if not os.path.exists(path):
            problems.append('%s is missing' % relative)
            continue
        src = open(path, encoding='utf-8').read()
        if 'def strip_dart_comments' not in src:
            problems.append('%s: no strip_dart_comments helper' % relative)
            continue
        if re.search(r"strip_dart_comments\([^()]*\.split\(';'\)", src):
            problems.append(
                '%s: splits on ";" before stripping comments, so a semicolon '
                'inside a doc comment truncates the enum body' % relative)
        if not re.search(r"strip_dart_comments\([^;]*?\)\.split\(';'\)", src):
            problems.append(
                '%s: does not strip comments before splitting the enum body'
                % relative)
    return problems


def main():
    problems = check_generators()
    checked = 0
    would_lose = 0

    for relative in SOURCES:
        path = os.path.join(ROOT, relative)
        if not os.path.exists(path):
            continue
        src = open(path, encoding='utf-8').read()
        for match in re.finditer(r'enum\s+(\w+)\s*\{(.*?)\}', src, re.S):
            name, body = match.group(1), match.group(2)
            checked += 1
            correct = parse(body, strip=True)
            naive = parse(body, strip=False)
            if not correct:
                problems.append(
                    '%s (%s): parsed no values at all' % (name, relative))
                continue
            would_lose += len([v for v in correct if v not in naive])

    if problems:
        print('Enum parsing FAILED:')
        for problem in problems:
            print('  - %s' % problem)
        return 1

    print('OK: %d enums parse to non-empty value lists.' % checked)
    print('    Comment stripping rescues %d value(s) that naive splitting '
          'would drop.' % would_lose)
    return 0


if __name__ == '__main__':
    sys.exit(main())
