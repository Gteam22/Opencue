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
FIRST_MEETING_SOURCE = os.path.join(
    ROOT, 'tool', 'data', 'first_meeting_library.json')
JSON_OUT = os.path.join(ROOT, 'assets', 'sample',
                        'conversation_library.json')
DART_OUT = os.path.join(ROOT, 'lib', 'data', 'seed',
                        'conversation_library.dart')
INTENT_DART_OUT = os.path.join(
    ROOT, 'lib', 'domain', 'conversation',
    'generated_first_meeting_intents.dart')


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


def _merge_lines(legacy_lines, first_meeting_lines):
    """Merge authored sources without introducing a second runtime format."""
    by_japanese = {}
    ordered = []
    duplicate_count = 0
    for line in legacy_lines + first_meeting_lines:
        japanese = line['japaneseText'].strip()
        existing = by_japanese.get(japanese)
        if existing is None:
            normalized = dict(line)
            normalized.setdefault('isFavorite', False)
            normalized.setdefault('isUserCreated', False)
            normalized.setdefault('timesShown', 0)
            normalized.setdefault('timesUsed', 0)
            normalized.setdefault('positiveResults', 0)
            normalized.setdefault('neutralResults', 0)
            normalized.setdefault('negativeResults', 0)
            by_japanese[japanese] = normalized
            ordered.append(normalized)
            continue

        duplicate_count += 1
        existing['topics'] = sorted(set(existing.get('topics', ())) |
                                    set(line.get('topics', ())))
        existing['tones'] = sorted(set(existing.get('tones', ())) |
                                   set(line.get('tones', ())))
        if not existing.get('englishMeaning') and line.get('englishMeaning'):
            existing['englishMeaning'] = line['englishMeaning']
        if not existing.get('translations') and line.get('translations'):
            existing['translations'] = line['translations']
        if not existing.get('koreanRomanization') and \
                line.get('koreanRomanization'):
            existing['koreanRomanization'] = line['koreanRomanization']
    return ordered, duplicate_count


def _dart_string(value):
    escaped = (value.replace('\\', '\\\\')
               .replace("'", "\\'")
               .replace('$', r'\$')
               .replace('\r', r'\r')
               .replace('\n', r'\n'))
    return "'%s'" % escaped


def _dart_string_list(values):
    return '<String>[%s]' % ', '.join(_dart_string(value) for value in values)


def _dart_collection_lines(field, values, collection='list'):
    opener, closer = ('<String>[', ']') if collection == 'list' else \
        ('<String>{', '}')
    output = ['    %s: %s' % (field, opener)]
    output.extend('      %s,' % _dart_string(value) for value in values)
    output.append('    %s,' % closer)
    return output


def _dart_description_lines(value):
    # Adjacent Dart string literals concatenate at compile time.
    chunks = [value[index:index + 48] for index in range(0, len(value), 48)]
    if len(chunks) == 1:
        return ['    description: %s,' % _dart_string(value)]
    return [
        '    description:',
        *['      %s' % _dart_string(chunk) for chunk in chunks[:-1]],
        '      %s,' % _dart_string(chunks[-1]),
    ]


def _write_generated_intents(intents, source_question_count):
    functions = {
        'question': 'question',
        'compliment': 'compliment',
        'tease': 'tease',
        'sharedInformation': 'sharedInformation',
        'invitation': 'invitation',
        'softRejection': 'softRejection',
        'agreement': 'agreement',
        'surprise': 'surprise',
        'interest': 'interest',
        'greeting': 'greeting',
        'thanks': 'thanks',
        'apology': 'apology',
        'goodbye': 'goodbye',
    }
    output = [
        '// GENERATED FILE. See tool/import_first_meeting_library.py and',
        '// tool/build_conversation_library.py.',
        "import 'conversation_intent.dart';",
        '',
        'const int generatedFirstMeetingSourceQuestionCount = %d;' %
        source_question_count,
        'const int generatedFirstMeetingIntentCount = %d;' % len(intents),
        '',
        'const List<ConversationIntentDefinition> generatedFirstMeetingIntents =',
        '    <ConversationIntentDefinition>[',
    ]
    for intent in intents:
        function = functions.get(intent['function'])
        if function is None:
            raise SystemExit('Unknown conversation function: %s' %
                             intent['function'])
        output.extend([
            '  ConversationIntentDefinition(',
            '    id: %s,' % _dart_string(intent['id']),
            *_dart_description_lines(intent['description']),
            *_dart_collection_lines('examples', intent['examples']),
            *_dart_collection_lines('keywords', intent['keywords']),
            *_dart_collection_lines('exclusions', intent['exclusions']),
            '    function: ConversationFunction.%s,' % function,
            *_dart_collection_lines(
                'contextTags', intent['contextTags'], collection='set'),
            *_dart_collection_lines('responseHints', intent['responseHints']),
            '    priority: %d,' % intent['priority'],
            '    confidenceThreshold: %s,' %
            intent['confidenceThreshold'],
            '  ),',
        ])
    output.append('];')
    output.append('')
    with open(INTENT_DART_OUT, 'w', encoding='utf-8', newline='\n') as handle:
        handle.write('\n'.join(output))


def main():
    records, ignored = parse_source(SOURCE)
    legacy_lines, duplicates = build(records)
    with open(FIRST_MEETING_SOURCE, encoding='utf-8') as handle:
        first_meeting = json.load(handle)
    if first_meeting.get('sourceQuestionCount') != 129:
        raise SystemExit('First-meeting source must contain 129 questions.')
    lines, cross_source_duplicates = _merge_lines(
        legacy_lines, first_meeting['lines'])
    _write_generated_intents(
        first_meeting['intents'], first_meeting['sourceQuestionCount'])
    payload = {
        'schemaVersion': 2,
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
    print('Conversation library: %d lines (%d legacy exact duplicates and '
          '%d cross-source Japanese duplicates removed).'
          % (len(lines), duplicates, cross_source_duplicates))
    print('First-meeting intents:', len(first_meeting['intents']))
    print('Categories:', dict(sorted(categories.items())))
    print('Boldness:', dict(sorted(boldness.items())))
    print('Narrative/source lines ignored:', len(ignored))
    return 0


if __name__ == '__main__':
    sys.exit(main())
