import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/recommendation/recommendation_models.dart';
import 'package:opencue/l10n/app_localizations.dart';
import 'package:opencue/l10n/strings_en.dart';
import 'package:opencue/l10n/strings_ja.dart';

void main() {
  const english = AppLocalizations(LanguageMode.english);
  const japanese = AppLocalizations(LanguageMode.japanese);
  const bilingual = AppLocalizations(LanguageMode.bilingual);

  group('tables', () {
    test('both languages define exactly the same keys', () {
      expect(stringsJa.keys.toSet(), stringsEn.keys.toSet());
    });

    test('no value is left empty', () {
      for (final entry in stringsEn.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
      for (final entry in stringsJa.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('placeholders match between the two languages', () {
      // A translation that drops {0} would render a message with a hole in it.
      final pattern = RegExp(r'\{(\d+)\}');
      for (final key in stringsEn.keys) {
        final inEnglish =
            pattern.allMatches(stringsEn[key]!).map((m) => m.group(1)).toSet();
        final inJapanese =
            pattern.allMatches(stringsJa[key]!).map((m) => m.group(1)).toSet();
        expect(inJapanese, inEnglish, reason: key);
      }
    });
  });

  group('enum coverage', () {
    test('every enum value has a label in both languages', () {
      // The generator enforces this too, but a hand-edit to the tables would
      // slip past it, and a missing label shows the user a raw key.
      for (final value in LocationTag.values) {
        expect(stringsEn, contains('location.${value.name}'));
        expect(stringsJa, contains('location.${value.name}'));
      }
      for (final value in ActivityTag.values) {
        expect(stringsEn, contains('activity.${value.name}'));
      }
      for (final value in GroupSize.values) {
        expect(stringsEn, contains('groupSize.${value.name}'));
      }
      for (final value in NoiseLevel.values) {
        expect(stringsEn, contains('noiseLevel.${value.name}'));
      }
      for (final value in Tone.values) {
        expect(stringsEn, contains('tone.${value.name}'));
      }
      for (final value in ObservableCue.values) {
        expect(stringsEn, contains('cue.${value.name}'));
      }
      for (final value in UseCondition.values) {
        expect(stringsEn, contains('condition.${value.name}'));
      }
      for (final value in AvoidCondition.values) {
        expect(stringsEn, contains('avoid.${value.name}'));
      }
      for (final value in LineCategory.values) {
        expect(stringsEn, contains('category.${value.name}'));
      }
      for (final value in InteractionOutcome.values) {
        expect(stringsEn, contains('outcome.${value.name}'));
      }
      for (final value in ContextSource.values) {
        expect(stringsEn, contains('source.${value.name}'));
      }
      for (final value in LibrarySort.values) {
        expect(stringsEn, contains('sort.${value.name}'));
      }
      for (final value in LanguageMode.values) {
        expect(stringsEn, contains('language.${value.name}'));
      }
      for (final value in AppThemePreference.values) {
        expect(stringsEn, contains('theme.${value.name}'));
      }

      // And the accessors actually resolve rather than echoing the key back.
      expect(english.location(LocationTag.bar), isNot(startsWith('location.')));
      expect(english.tone(Tone.playful), isNot(startsWith('tone.')));
      expect(
        english.avoidCondition(AvoidCondition.headphonesOn),
        isNot(startsWith('avoid.')),
      );
    });

    test('every score factor code has a label', () {
      // Score explanations are codes rather than English prose precisely so
      // they can be translated; an unlabelled code defeats that.
      for (final code in ScoreFactorCode.values) {
        expect(stringsEn, contains('factor.${code.name}'));
        expect(stringsJa, contains('factor.${code.name}'));
      }
    });

    test('every directness step has a label', () {
      for (var value = kMinDirectness; value <= kMaxDirectness; value++) {
        expect(english.directnessLabel(value), isNotEmpty);
        expect(english.directnessLabel(value), isNot(contains('directness.')));
      }
    });
  });

  group('lookup behaviour', () {
    test('Japanese mode returns Japanese text', () {
      expect(japanese.t('nav.home'), stringsJa['nav.home']);
    });

    test('English and bilingual modes return English interface text', () {
      expect(english.t('nav.home'), stringsEn['nav.home']);
      expect(bilingual.t('nav.home'), stringsEn['nav.home']);
    });

    test('an unknown key returns the key rather than throwing', () {
      // Better a visible key in one corner of the UI than a crash, and the
      // check_strings_used.py script catches these before release.
      expect(english.t('no.such.key'), 'no.such.key');
    });

    test('formatting substitutes positional arguments', () {
      final formatted = english.f('history.recordCount', <Object?>[7]);
      expect(formatted, contains('7'));
      expect(formatted, isNot(contains('{0}')));
    });

    test('formatting leaves an unsupplied placeholder alone', () {
      final formatted = english.f('history.recordCount', const <Object?>[]);
      expect(formatted, contains('{0}'));
    });

    test('the English meaning is hidden only in Japanese mode', () {
      expect(english.showEnglishMeaning, isTrue);
      expect(bilingual.showEnglishMeaning, isTrue);
      expect(japanese.showEnglishMeaning, isFalse);
    });
  });

  group('domain messages', () {
    test('resolves a bare key from the data layer', () {
      expect(
        english.message('import.error.emptyFile'),
        stringsEn['import.error.emptyFile'],
      );
    });

    test('resolves a key:detail message into the formatted string', () {
      final resolved = english.message('import.warning.invalidLine:42');
      expect(resolved, contains('42'));
      expect(resolved, isNot(contains('{0}')));
    });

    test('passes an unknown message through unchanged', () {
      expect(english.message('something.unmapped'), 'something.unmapped');
    });
  });

  group('the advisory wording', () {
    test('is exactly the sentence the specification requires', () {
      expect(
        stringsEn['advisory.title'],
        'This may not be a good time to approach.',
      );
      expect(stringsJa['advisory.title'], isNotNull);
      expect(stringsJa['advisory.title'], isNotEmpty);
    });
  });

  group('respectful wording', () {
    test('no outcome label frames a person as a success or a failure', () {
      // The specification is explicit about this, and it is the sort of thing
      // that gets reintroduced by a well-meaning edit.
      const forbidden = <String>[
        'success',
        'successful',
        'failure',
        'failed',
        'target',
        'reject',
        'rejection',
      ];
      for (final outcome in InteractionOutcome.values) {
        final label = stringsEn['outcome.${outcome.name}']!.toLowerCase();
        for (final word in forbidden) {
          expect(
            label,
            isNot(contains(word)),
            reason: 'outcome.${outcome.name} contains "$word"',
          );
        }
      }
    });

    test('the privacy statement covers every promise the app makes', () {
      final privacy = <String>[
        stringsEn['about.privacyLocal']!,
        stringsEn['about.privacyNoCamera']!,
        stringsEn['about.privacyNoMic']!,
        stringsEn['about.privacyNoProfiling']!,
        stringsEn['about.privacyNotes']!,
        stringsEn['about.privacyNoTelemetry']!,
        stringsEn['about.privacyFuture']!,
      ].join(' ').toLowerCase();
      expect(privacy, contains('camera'));
      expect(privacy, contains('microphone'));
      expect(privacy, contains('local'));
    });
  });
}
