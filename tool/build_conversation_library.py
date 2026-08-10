#!/usr/bin/env python3
"""Build the manually browsed adult conversation library.

The source is the tabular/prose dataset in ``tool/data/lhdata.txt``.  This
normalizer keeps every multilingual row, removes exact duplicate triples,
adds stable browsing metadata, generates practical Korean romanization, and
emits both a readable JSON asset and the embedded Dart seed used at startup.

Run from the repository root:

    python tool/build_conversation_library.py
"""

from collections import Counter
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import korean_romanize  # noqa: E402


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'tool', 'data', 'lhdata.txt')
JSON_OUT = os.path.join(ROOT, 'assets', 'sample',
                        'conversation_library.json')
DART_OUT = os.path.join(ROOT, 'lib', 'data', 'seed',
                        'conversation_library.dart')


def _slug(text):
    return re.sub(r'[^a-z0-9]+', '-', text.lower()).strip('-')


def parse_source(path):
    """Return ordered ``(section, jp, en, ko)`` records from the mixed file."""
    raw = open(path, encoding='utf-8').read().splitlines()
    records = []
    section = ''
    index = 0
    ignored_prose = []

    while index < len(raw):
        line = raw[index]
        fields = line.split('\t')

        if len(fields) == 4 and fields[0].isdigit():
            records.append((section, fields[1], fields[2], fields[3]))
        elif len(fields) == 3 and fields[0] != 'Japanese':
            # The source omitted the heading for the would-you-rather table.
            if section.startswith('12. Clever double meanings'):
                section = '13. Flirty would-you-rather games'
            records.append((section, fields[0], fields[1], fields[2]))
        elif (line.startswith('Japanese:') and index + 2 < len(raw)
              and raw[index + 1].startswith('English:')
              and raw[index + 2].startswith('Korean:')):
            records.append((
                section,
                line[len('Japanese:'):].strip(),
                raw[index + 1][len('English:'):].strip(),
                raw[index + 2][len('Korean:'):].strip(),
            ))
            index += 2
        elif (line.strip() and len(fields) == 1
              and not line.startswith(('#', 'These ', 'That ', 'Use ',
                                       'For ', 'Instead ', 'A particularly',
                                       '→', '「'))):
            # Section headings are short labels. Narrative commentary is kept
            # out of the data and reported rather than guessed into a phrase.
            if (len(line) < 90 and not line.endswith(('.', ':'))
                    and not line.startswith(('English:', 'Korean:'))):
                section = line.strip()
            else:
                ignored_prose.append(line.strip())
        index += 1

    return records, ignored_prose


def category_for(section, english):
    s = section.lower()
    e = english.lower()
    if 'gentleman-style responses' in s:
        return 'comebacks'
    if 'gentleman' in s or any(x in s for x in (
            'elegant compliments', 'romantic with', 'classy',
            'understated confidence', 'almost too smooth')):
        return 'gentleman'
    if 'sophisticated lines about kissing' in s or 'teasing about kissing' in s:
        return 'kissing'
    if 'turn her answer' in s or 'she teases you' in s:
        return 'comebacks'
    if any(x in s for x in ('fake rules', 'hypothetical', 'would-you-rather',
                            'confession game')):
        return 'games'
    if 'playfully suspicious' in s:
        return 'playful'
    if 'you and me' in s:
        return 'flirty'
    if any(x in s for x in ('pretending to be innocent',
                            'scientific investigation', 'witty compliments',
                            'fake accusations', 'double meanings')):
        return 'witty'
    if 'explicit' in s or 'preferences / sexual' in s or 'fantasies' in s:
        return 'intimate'
    if 'getting naughtier' in s:
        return 'naughty'
    if 'about attraction' in s or 'directly flirt' in s:
        return 'kissing' if 'kiss' in e else 'flirty'
    if 'flirty / suggestive' in s:
        if 'kiss' in e:
            return 'kissing'
        return 'questions'
    return 'playful'


def boldness_for(section, english, category):
    s = section.lower()
    e = english.lower()
    if any(x in s for x in ('explicit', 'fantasies / bold')):
        return 'explicit'
    if 'preferences / sexual compatibility' in s:
        explicit_words = ('position', 'orgasm', 'oral', 'anal', 'sex',
                          'masturbat', 'fetish', 'porn', 'naked')
        return 'explicit' if any(word in e for word in explicit_words) else 'naughty'
    if 'getting naughtier' in s:
        return 'naughty'
    if category in ('naughty', 'intimate'):
        return 'naughty'
    if any(x in s for x in ('hypothetical', 'double meanings',
                            'would-you-rather', 'confession game')):
        return 'naughty'
    if category in ('kissing', 'flirty', 'gentleman'):
        return 'flirty'
    if category in ('witty', 'comebacks'):
        return 'flirty'
    return 'light'


def usage_for(section, english, category):
    if category == 'comebacks' or 'responses when' in section.lower():
        return 'comeback'
    if category == 'games':
        return 'game'
    return 'question' if '?' in english else 'statement'


def tones_for(section, category, english):
    if 'core cue responses' in section.lower():
        tones = {'friendly'}
        if any(word in english.lower() for word in ('interview', 'why', 'guess')):
            tones.add('playful')
        return sorted(tones)
    tones = {'flirty'}
    if category in ('playful', 'witty', 'games', 'comebacks'):
        tones.add('playful')
    if category == 'witty':
        tones.add('witty')
    if category == 'gentleman':
        tones.update(('classy', 'confident'))
    if category in ('naughty', 'intimate'):
        tones.update(('direct', 'suggestive'))
    if category == 'kissing':
        tones.add('romantic')
    low = (section + ' ' + english).lower()
    if any(word in low for word in ('innocent', 'research', 'statistics')):
        tones.add('witty')
    if any(word in low for word in ('laugh', 'hilarious', 'funny', '😂')):
        tones.add('humorous')
    if any(word in low for word in ('teas', 'tempt', 'danger')):
        tones.add('teasing')
    return sorted(tones)


TOPIC_WORDS = {
    'kissing': ('kiss', 'kisser'),
    'attraction': ('attract', 'sexy', 'chemistry', 'turn you on'),
    'touch': ('touch', 'cuddle', 'hug', 'hands', 'neck'),
    'dominance': ('dominant', 'submissive', 'taking the lead', 'being led',
                  's or m', 's/m'),
    'drinking': ('drink', 'drunk', 'alcohol', 'bar'),
    'preferences': ('prefer', 'favorite', 'which do you', 'or '),
    'fantasy': ('fantas', 'imagination', 'imagine'),
    'compatibility': ('compatib', 'relationship'),
    'games': ('game', 'points', 'score', 'rules', 'hypothetical'),
    'compliments': ('beautiful', 'cute', 'smile', 'look at me', 'outfit'),
}


def topics_for(section, category, english):
    low = (section + ' ' + english).lower()
    topics = {category}
    if 'relationship status' in low:
        topics.update(('relationships', 'dating'))
    if 'time in japan' in low:
        topics.update(('travel', 'japanese'))
    for topic, words in TOPIC_WORDS.items():
        if any(word in low for word in words):
            topics.add(topic)
    if 'gentleman' in low or category == 'gentleman':
        topics.add('gentleman')
    return sorted(topics)


def build(records):
    seen = set()
    lines = []
    per_category = Counter()
    duplicate_count = 0

    for section, jp, en, ko in records:
        jp, en, ko = jp.strip(), en.strip(), ko.strip()
        key = (jp, en, ko)
        if key in seen:
            duplicate_count += 1
            continue
        seen.add(key)
        if not jp or not en or not ko:
            raise SystemExit('Empty required text in section %r' % section)

        category = category_for(section, en)
        per_category[category] += 1
        sequence = per_category[category]
        romanized, _ = korean_romanize.romanize(ko)
        boldness = boldness_for(section, en, category)
        usage = usage_for(section, en, category)

        lines.append({
            'id': 'conversation-%s-%03d' % (category, sequence),
            'japaneseText': jp,
            'englishMeaning': en,
            'translations': {'ko': ko},
            'koreanRomanization': romanized,
            'category': category,
            'tones': tones_for(section, category, en),
            'directness': {'light': 2, 'flirty': 3,
                           'naughty': 4, 'explicit': 5}[boldness],
            'boldness': boldness,
            'usageType': usage,
            'topics': topics_for(section, category, en),
            'manualOnly': True,
            'tts': {'jp': True, 'ko': True},
            'notes': 'Source family: %s' % section,
            'isFavorite': False,
            'isUserCreated': False,
            'timesShown': 0,
            'timesUsed': 0,
            'positiveResults': 0,
            'neutralResults': 0,
            'negativeResults': 0,
        })

    return lines, duplicate_count


def main():
    records, ignored = parse_source(SOURCE)
    lines, duplicates = build(records)
    payload = {
        'schemaVersion': 1,
        'app': 'OpenCue',
        'kind': 'manualConversationLibrary',
        'manualBrowsingOnly': True,
        'lines': lines,
    }

    pretty = json.dumps(payload, ensure_ascii=False, indent=2)
    with open(JSON_OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write(pretty + '\n')

    compact = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    if "'''" in compact:
        raise SystemExit("Generated JSON contains Dart raw-string terminator")
    with open(DART_OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('// GENERATED FILE. See tool/build_conversation_library.py.\n')
        handle.write("const String conversationLibraryJson = r'''\n")
        # Pretty JSON keeps repository symbol/lint checks fast; a single
        # 200k-character source line makes regex-based static checks crawl.
        handle.write(pretty)
        handle.write("\n''';\n")

    categories = Counter(line['category'] for line in lines)
    boldness = Counter(line['boldness'] for line in lines)
    print('Conversation library: %d lines (%d exact duplicates removed).'
          % (len(lines), duplicates))
    print('Categories:', dict(sorted(categories.items())))
    print('Boldness:', dict(sorted(boldness.items())))
    print('Narrative/source lines ignored:', len(ignored))
    return 0


if __name__ == '__main__':
    sys.exit(main())
