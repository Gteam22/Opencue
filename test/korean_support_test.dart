// Korean language support.
//
// Covers the three things that could quietly break: a line's Korean twin
// surviving every round trip (JSON, DB, copyWith), the display logic that
// decides what each language mode shows, and the seed actually carrying Korean
// for all 155 lines.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/data/seed/seed_loader.dart';
import 'package:opencue/domain/models/opener_line.dart';

OpenerLine _koreanLine() => OpenerLine(
      id: 'seed-universal-02',
      japaneseText: 'すごくいい雰囲気ですね。',
      englishMeaning: 'You have a really nice vibe.',
      translations: const <String, String>{'ko': '분위기가 정말 좋으시네요.'},
      koreanRomanization: 'Bunwigiga jeongmal joeusineyo.',
    );

void main() {
  group('a line carries its translations', () {
    test('koreanText and textFor read the map', () {
      final line = _koreanLine();
      expect(line.koreanText, '분위기가 정말 좋으시네요.');
      expect(line.textFor('ko'), '분위기가 정말 좋으시네요.');
      // Japanese is not in the map; textFor falls back to it rather than
      // returning a blank, so a partly-translated library never shows holes.
      expect(line.textFor('ja'), 'すごくいい雰囲気ですね。');
      expect(line.textFor('zh'), 'すごくいい雰囲気ですね。');
    });

    test('a line with no Korean reports null, not empty string', () {
      final line = OpenerLine(id: 'x', japaneseText: 'テスト');
      expect(line.koreanText, isNull);
      expect(line.translations, isEmpty);
    });
  });

  group('round trips', () {
    test('JSON preserves Korean and romanization', () {
      final line = _koreanLine();
      final restored = OpenerLine.fromJson(
        jsonDecode(line.encode()) as Map<String, Object?>,
      );
      expect(restored.koreanText, line.koreanText);
      expect(restored.koreanRomanization, line.koreanRomanization);
    });

    test('a line without Korean serialises without the keys', () {
      // The fields must be omitted when empty so existing exports are
      // byte-for-byte unchanged by this feature.
      final line = OpenerLine(id: 'x', japaneseText: 'テスト');
      final json = jsonDecode(line.encode()) as Map<String, Object?>;
      expect(json.containsKey('translations'), isFalse);
      expect(json.containsKey('koreanRomanization'), isFalse);
    });

    test('the DB map round-trips through a JSON column', () {
      final line = _koreanLine();
      final row = line.toDbMap();
      expect(row['translations'], isA<String>());
      final restored = OpenerLine.fromDbRow(row);
      expect(restored.koreanText, line.koreanText);
      expect(restored.koreanRomanization, line.koreanRomanization);
    });

    test('a null translations column decodes to an empty map', () {
      final line = OpenerLine(id: 'x', japaneseText: 'テスト');
      final row = line.toDbMap();
      expect(row['translations'], isNull);
      expect(OpenerLine.fromDbRow(row).translations, isEmpty);
    });

    test('a corrupt translations column costs the translations, not the line',
        () {
      final row = _koreanLine().toDbMap()..['translations'] = '{not json';
      final restored = OpenerLine.fromDbRow(row);
      expect(restored.translations, isEmpty);
      // The rest of the line survives.
      expect(restored.japaneseText, 'すごくいい雰囲気ですね。');
    });

    test('copyWith carries translations forward untouched', () {
      final line = _koreanLine();
      final favourited = line.copyWith(isFavorite: true);
      expect(favourited.koreanText, line.koreanText);
      expect(favourited.koreanRomanization, line.koreanRomanization);
    });
  });

  group('language mode display logic', () {
    test('showsJapanese and showsKorean per mode', () {
      expect(LanguageMode.japanese.showsJapanese, isTrue);
      expect(LanguageMode.japanese.showsKorean, isFalse);

      expect(LanguageMode.korean.showsKorean, isTrue);
      expect(LanguageMode.korean.showsJapanese, isFalse);

      // Both shows one entry in two scripts at once.
      expect(LanguageMode.both.showsJapanese, isTrue);
      expect(LanguageMode.both.showsKorean, isTrue);

      // The three original modes are unchanged.
      expect(LanguageMode.english.showsJapanese, isTrue);
      expect(LanguageMode.english.showsKorean, isFalse);
      expect(LanguageMode.bilingual.showsJapanese, isTrue);
      expect(LanguageMode.bilingual.showsKorean, isFalse);
    });

    test('interface chrome falls back to a translated language', () {
      // Korean chrome is not translated yet, so Korean and Both borrow the
      // English interface while showing Korean lines.
      expect(LanguageMode.korean.interfaceLanguage, LanguageMode.english);
      expect(LanguageMode.both.interfaceLanguage, LanguageMode.english);
      expect(LanguageMode.japanese.interfaceLanguage, LanguageMode.japanese);
      expect(
        LanguageMode.bilingual.interfaceLanguage,
        LanguageMode.bilingual,
      );
    });

    test('adding modes did not disturb the original three values', () {
      // Their index positions are load-bearing: a stored settings value is
      // parsed by name, but a stray reorder would still be a nasty surprise.
      expect(LanguageMode.values.indexOf(LanguageMode.japanese), 0);
      expect(LanguageMode.values.indexOf(LanguageMode.english), 1);
      expect(LanguageMode.values.indexOf(LanguageMode.bilingual), 2);
    });
  });

  group('the seed carries Korean for every line', () {
    const loader = SeedLoader();
    final lines = loader.load();

    test('all 155 starter lines have Korean text', () {
      final withoutKorean =
          lines.where((l) => l.koreanText == null).map((l) => l.id).toList();
      expect(withoutKorean, isEmpty,
          reason: 'these seed lines lost their Korean: $withoutKorean');
      expect(lines.length, greaterThanOrEqualTo(155));
    });

    test('every Korean line also has a romanization', () {
      final missing = lines
          .where((l) => l.koreanText != null)
          .where((l) =>
              l.koreanRomanization == null || l.koreanRomanization!.isEmpty)
          .map((l) => l.id)
          .toList();
      expect(missing, isEmpty);
    });

    test('romanization is Roman letters, not leftover Hangul', () {
      final hangul = RegExp('[\uac00-\ud7a3]');
      final leaked = lines
          .where((l) => l.koreanRomanization != null)
          .where((l) => hangul.hasMatch(l.koreanRomanization!))
          .map((l) => l.id)
          .toList();
      expect(leaked, isEmpty,
          reason: 'romanization still contains Hangul: $leaked');
    });

    test('the vibe line matches the brief example', () {
      final line =
          lines.firstWhere((l) => l.id == 'seed-universal-02');
      expect(line.koreanText, '분위기가 정말 좋으시네요.');
      expect(line.koreanRomanization, startsWith('Bunwigiga jeongmal'));
    });
  });

  group('the romanization setting persists', () {
    test('defaults on, and survives a JSON round trip when off', () {
      const settings = AppSettings();
      expect(settings.showKoreanRomanization, isTrue);

      final off = settings.copyWith(showKoreanRomanization: false);
      final restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(off.toJson())) as Map<String, Object?>,
      );
      expect(restored.showKoreanRomanization, isFalse);
    });

    test('survives the settings string-map round trip', () {
      final off = const AppSettings().copyWith(showKoreanRomanization: false);
      final restored = AppSettings.fromStringMap(off.toStringMap());
      expect(restored.showKoreanRomanization, isFalse);
    });

    test('an old settings blob with no romanization key defaults to on', () {
      // Forward compatibility: a settings record written before this feature
      // has no key, and the reader must treat its absence as the default.
      final restored = AppSettings.fromJson(
        <String, Object?>{'languageMode': 'korean'},
      );
      expect(restored.showKoreanRomanization, isTrue);
      expect(restored.languageMode, LanguageMode.korean);
    });
  });
}
