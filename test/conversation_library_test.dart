import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/seed/conversation_seed_loader.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/context_snapshot.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/recommendation/recommendation_engine.dart';
import 'package:opencue/domain/recommendation/recommendation_models.dart';
import 'package:opencue/domain/repositories/library_query.dart';
import 'package:opencue/l10n/app_localizations.dart';

void main() {
  const loader = ConversationSeedLoader();
  final lines = loader.load(createdAt: DateTime.utc(2026));
  final legacy = lines.where((line) => line.id.startsWith('conversation-'));
  final firstMeeting =
      lines.where((line) => line.id.startsWith('first-meeting-'));

  group('generated conversation dataset', () {
    test('loads all normalized multilingual records with unique ids', () {
      expect(lines, hasLength(652));
      expect(legacy, hasLength(329));
      expect(firstMeeting, hasLength(323));
      expect(lines.map((line) => line.id).toSet(), hasLength(lines.length));
      for (final line in lines) {
        expect(line.japaneseText.trim(), isNotEmpty, reason: line.id);
        if (line.id.startsWith('conversation-')) {
          expect(line.englishMeaning?.trim(), isNotEmpty, reason: line.id);
          expect(line.koreanText?.trim(), isNotEmpty, reason: line.id);
          expect(line.koreanRomanization?.trim(), isNotEmpty, reason: line.id);
        }
        expect(line.boldness, isNotNull, reason: line.id);
        expect(line.usageType, isNotNull, reason: line.id);
        expect(line.manualOnly, isTrue, reason: line.id);
        expect(line.isValid, isTrue, reason: line.id);
      }
    });

    test('category and boldness counts stay stable', () {
      int category(LineCategory value) =>
          legacy.where((line) => line.category == value).length;
      int boldness(ConversationBoldness value) =>
          legacy.where((line) => line.boldness == value).length;

      expect(category(LineCategory.comebacks), 30);
      expect(category(LineCategory.flirty), 34);
      expect(category(LineCategory.games), 39);
      expect(category(LineCategory.gentleman), 48);
      expect(category(LineCategory.intimate), 50);
      expect(category(LineCategory.kissing), 31);
      expect(category(LineCategory.naughty), 20);
      expect(category(LineCategory.playful), 12);
      expect(category(LineCategory.questions), 13);
      expect(category(LineCategory.witty), 52);

      expect(boldness(ConversationBoldness.light), 35);
      expect(boldness(ConversationBoldness.flirty), 185);
      expect(boldness(ConversationBoldness.naughty), 73);
      expect(boldness(ConversationBoldness.explicit), 36);
    });

    test('romanization is separate and contains no Hangul', () {
      final hangul = RegExp('[\uac00-\ud7a3]');
      for (final line in legacy) {
        expect(hangul.hasMatch(line.koreanRomanization!), isFalse,
            reason: line.id);
        expect(line.koreanRomanization, isNot(line.koreanText));
      }
    });

    test('conversation metadata survives JSON and SQLite mappings', () {
      final original = lines.first;
      final fromJson = OpenerLine.fromJson(original.toJson());
      final fromDb = OpenerLine.fromDbRow(original.toDbMap());
      for (final restored in <OpenerLine>[fromJson, fromDb]) {
        expect(restored.boldness, original.boldness);
        expect(restored.usageType, original.usageType);
        expect(restored.topics, original.topics);
        expect(restored.manualOnly, isTrue);
        expect(restored.ttsJapanese, isTrue);
        expect(restored.ttsKorean, isTrue);
      }
    });
  });

  group('manual search and filters', () {
    test('searches English, Korean, romanization and metadata', () {
      expect(const LibraryQuery(searchText: 'kiss').applyTo(lines), isNotEmpty);
      expect(const LibraryQuery(searchText: '키스').applyTo(lines), isNotEmpty);
      expect(
        const LibraryQuery(searchText: 'gentleman').applyTo(lines),
        isNotEmpty,
      );
      expect(const LibraryQuery(searchText: 'S M').applyTo(lines), isNotEmpty);

      final romanToken = lines.first.koreanRomanization!.split(' ').first;
      expect(LibraryQuery(searchText: romanToken).applyTo(lines), isNotEmpty);
    });

    test('filters category, boldness and usage type', () {
      final result = const LibraryQuery(
        categories: <LineCategory>{LineCategory.intimate},
        boldness: <ConversationBoldness>{ConversationBoldness.explicit},
        usageTypes: <ConversationUsageType>{ConversationUsageType.question},
      ).applyTo(lines);
      expect(result, isNotEmpty);
      expect(result.every((line) => line.category == LineCategory.intimate),
          isTrue);
      expect(
        result.every((line) => line.boldness == ConversationBoldness.explicit),
        isTrue,
      );
      expect(
        result.every(
          (line) => line.usageType == ConversationUsageType.question,
        ),
        isTrue,
      );
    });
  });

  group('display modes', () {
    test('Japanese, Korean and Both expose the intended scripts', () {
      expect(
        const AppLocalizations(LanguageMode.japanese).showsJapaneseLines,
        isTrue,
      );
      expect(
        const AppLocalizations(LanguageMode.korean).showsKoreanLines,
        isTrue,
      );
      const both = AppLocalizations(LanguageMode.both);
      expect(both.showsJapaneseLines, isTrue);
      expect(both.showsKoreanLines, isTrue);
      expect(both.showEnglishMeaning, isTrue);
    });

    test('romanization toggle only affects modes that show Korean', () {
      expect(
        const AppLocalizations(
          LanguageMode.korean,
          romanizeKorean: true,
        ).showKoreanRomanization,
        isTrue,
      );
      expect(
        const AppLocalizations(
          LanguageMode.korean,
          romanizeKorean: false,
        ).showKoreanRomanization,
        isFalse,
      );
      expect(
        const AppLocalizations(
          LanguageMode.japanese,
          romanizeKorean: true,
        ).showKoreanRomanization,
        isFalse,
      );
    });
  });

  test('manual-only lines are never automatically recommended', () {
    final result = const RecommendationEngine().recommend(
      context: ContextSnapshot(),
      library: lines,
    );
    expect(result.primary, isEmpty);
    expect(result.alternates, isEmpty);
    expect(
      result.excluded.every(
        (entry) => entry.reason == ExclusionReason.manualOnly,
      ),
      isTrue,
    );
  });
}
