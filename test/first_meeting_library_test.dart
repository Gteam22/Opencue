import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/seed/conversation_seed_loader.dart';
import 'package:opencue/domain/conversation/conversation_intent_catalog.dart';
import 'package:opencue/domain/conversation/conversation_intent_matcher.dart';
import 'package:opencue/domain/conversation/conversation_models.dart';
import 'package:opencue/domain/conversation/conversation_response_engine.dart';

import '../lib/domain/conversation/conversation_assist_controller.dart';
import '../lib/domain/conversation/conversation_recognition_service.dart';

void main() {
  const matcher = ConversationIntentMatcher();

  group('first-meeting intent variants', () {
    final cases = <String, String>{
      'どこ出身？': 'ask_origin',
      'どこの国ですか？': 'ask_origin',
      '出身どこですか？': 'ask_origin',
      'どちらのご出身ですか？': 'ask_origin',
      '日本に来てどのくらいですか？': 'time_in_japan',
      '日本何年目ですか？': 'time_in_japan',
      'こっち長いんですか？': 'time_in_japan',
      'なんで日本に来たの？': 'ask_reason_japan',
      'なんで日本に来たんですか？': 'ask_reason_japan',
      '日本に来たきっかけは？': 'ask_reason_japan',
      'どうして日本に住もうと思ったんですか？': 'ask_reason_japan',
      '日本語上手ですね': 'compliment_japanese',
      '日本語ペラペラですね。': 'compliment_japanese',
      'どこで日本語勉強したんですか？': 'japanese_study_method',
      '日本語どうやって覚えたの？': 'japanese_study_method',
      '日本食好きですか？': 'likes_japanese_food',
      '何の日本食が好き？': 'favorite_japanese_food',
      '納豆食べられますか？': 'can_eat_natto',
      '納豆いける？': 'can_eat_natto',
      '刺身大丈夫？': 'can_eat_sashimi',
      '箸使える？': 'can_use_chopsticks',
      '何の仕事してるんですか？': 'ask_job',
      '仕事何してるの？': 'ask_job',
      '英語の先生ですか？': 'english_teacher_assumption',
      '趣味は何ですか？': 'ask_hobbies',
      '趣味何？': 'ask_hobbies',
      '休みの日何してる？': 'days_off',
      '普段何して遊ぶの？': 'ask_hobbies',
      '彼女いますか？': 'relationship_status',
      '今彼女いる？': 'relationship_status',
      '恋人いるの？': 'relationship_status',
      '彼女とかいるんですか？': 'relationship_status',
      '今フリー？': 'single_status',
      '結婚してますか？': 'ask_married',
      '既婚ですか？': 'ask_married',
      'どんな女性がタイプ？': 'ask_type',
      '好きなタイプは？': 'ask_type',
      '年上と年下どっちが好き？': 'age_preference',
      '一人暮らし？': 'living_alone',
      '誰かと住んでる？': 'living_alone',
      'どこに住んでるの？': 'ask_residence',
      'このあとどうするんですか？': 'plans_after_this',
      'このあと予定ある？': 'plans_after_this',
      '何時までいるの？': 'how_late_staying',
      '何時まで飲むんですか？': 'how_late_staying',
    };

    for (final entry in cases.entries) {
      test('${entry.key} -> ${entry.value}', () {
        final matches = matcher.match(entry.key);
        expect(matches, isNotEmpty);
        expect(matches.first.id, entry.value);
      });
    }
  });

  test('all 129 source families are represented by generated intent data', () {
    expect(generatedFirstMeetingSourceQuestionCount, 129);
    expect(generatedFirstMeetingIntentCount, 128);
    final firstMeeting = conversationIntentCatalog.where(
      (intent) => intent.responseHints.contains(intent.id),
    );
    expect(firstMeeting.length, greaterThanOrEqualTo(128));
    expect(
      conversationIntentCatalog.map((intent) => intent.id).toSet(),
      containsAll(<String>{
        'ask_origin',
        'time_in_japan',
        'relationship_status',
        'single_status',
        'continue_more',
      }),
    );
  });

  group('actual library returns intent-linked responses end to end', () {
    final cases = <String, String>{
      '日本に来てどのくらいですか？': 'time_in_japan',
      '日本語どうやって覚えたの？': 'japanese_study_method',
      '彼女とかいるんですか？': 'relationship_status',
      'このあと予定ある？': 'plans_after_this',
      '何の日本食が好き？': 'favorite_japanese_food',
      '納豆食べれる？': 'can_eat_natto',
      '何の仕事してるの？': 'ask_job',
    };

    for (final entry in cases.entries) {
      test('${entry.key} returns ${entry.value} response family', () {
        final library = const ConversationSeedLoader().load(
          createdAt: DateTime.utc(2026),
        );
        final result = const ConversationResponseEngine().suggest(
          transcript: entry.key,
          library: library,
          preferences: const ConversationPreferences(),
        );

        expect(result.interpretation.primaryIntentId, entry.value);
        expect(result.suggestions, isNotEmpty);
        expect(result.suggestions.first.line.topics, contains(entry.value));
        expect(result.suggestions.first.reasons, contains('intentFamily'));
      });
    }
  });

  test('finalized speech replaces cues with the intended response family',
      () async {
    final controller = ConversationAssistController(
      recognition: const NullConversationRecognitionService(),
    );
    addTearDown(controller.dispose);
    final library = const ConversationSeedLoader().load(
      createdAt: DateTime.utc(2026),
    );
    final cases = <String, String>{
      '日本に来てどのくらいですか？': 'time_in_japan',
      '彼女いる？': 'relationship_status',
      '納豆食べれる？': 'can_eat_natto',
      '何の仕事してるの？': 'ask_job',
      'このあと何する？': 'plans_after_this',
    };

    for (final entry in cases.entries) {
      final updated = await controller.onUtteranceFinalized(
        entry.key,
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(updated, isTrue, reason: entry.key);
      expect(controller.result!.interpretation.primaryIntentId, entry.value);
      expect(
        controller.result!.suggestions.first.line.topics,
        contains(entry.value),
      );
    }
    expect(controller.cueRevision, cases.length);
  });

  test('local matching remains fast with the expanded static catalog', () {
    final stopwatch = Stopwatch()..start();
    for (var index = 0; index < 200; index++) {
      matcher.match('日本に来てどのくらいですか？');
    }
    stopwatch.stop();
    expect(stopwatch.elapsedMilliseconds, lessThan(2000));
  });
}
