import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/opener_line.dart';

import '../lib/domain/conversation/conversation_assist_controller.dart';
import '../lib/domain/conversation/conversation_intent_catalog.dart';
import '../lib/domain/conversation/conversation_intent_matcher.dart';
import '../lib/domain/conversation/conversation_interpreter.dart';
import '../lib/domain/conversation/conversation_models.dart';
import '../lib/domain/conversation/conversation_recognition_service.dart';
import '../lib/domain/conversation/conversation_response_engine.dart';
import '../lib/domain/conversation/language_detector.dart';
import '../lib/domain/conversation/voice_activity_tracker.dart';

void main() {
  test('adult assist opt-in is off by default and persists explicitly', () {
    expect(AppSettings.defaults.conversationAssistAdultContentEnabled, isFalse);
    final enabled = AppSettings.defaults.copyWith(
      conversationAssistAdultContentEnabled: true,
    );
    expect(
      AppSettings.fromStringMap(enabled.toStringMap())
          .conversationAssistAdultContentEnabled,
      isTrue,
    );
  });

  group('multilingual understanding', () {
    const detector = ConversationLanguageDetector();

    test('detects Japanese, Korean, and English independently', () {
      expect(detector.detect('週末は何をするの？'), DetectedLanguage.japanese);
      expect(detector.detect('주말에 뭐 해요?'), DetectedLanguage.korean);
      expect(detector.detect('What are you doing this weekend?'),
          DetectedLanguage.english);
    });
  });

  group('data-driven intent catalog', () {
    const matcher = ConversationIntentMatcher();
    const interpreter = ConversationInterpreter();

    test('ships at least 100 maintainable high-value intents', () {
      expect(conversationIntentCatalog.length, greaterThanOrEqualTo(100));
      expect(
        conversationIntentCatalog.map((intent) => intent.id).toSet().length,
        conversationIntentCatalog.length,
      );
      expect(
        conversationIntentCatalog.every((intent) =>
            intent.examples.length >= 5 && intent.responseHints.length >= 5),
        isTrue,
      );
    });

    test('natural eye compliment variations share one semantic intent', () {
      for (final phrase in <String>[
        '目の色が綺麗',
        '目きれいだね',
        '瞳がすごく綺麗',
        '綺麗な目してるね',
        '目が印象的',
      ]) {
        expect(matcher.match(phrase).first.id, 'compliment_eyes');
      }
    });

    test('recognizes relationship, teasing, availability and invitation', () {
      expect(matcher.match('彼女いるの？').first.id,
          'ask_relationship_status');
      expect(matcher.match('モテそう').first.id, 'tease_popular');
      expect(matcher.match('今週末何してる？').first.id,
          'ask_weekend_plans');
      expect(matcher.match('また飲もう').first.id, 'invite_drink_again');
    });

    test('actionable question outranks a passive compliment', () {
      final result = interpreter.interpret(
        '日本語上手ですね。日本にどのくらいいるんですか？',
      );
      expect(result.primaryIntentId, 'ask_time_in_japan');
      expect(result.isQuestion, isTrue);
    });

    test('recent context can strengthen an otherwise equal match', () {
      final result = matcher.match(
        'Are you free this weekend?',
        recentTranscripts: const <String>['weekend plans'],
      );
      expect(result, isNotEmpty);
      expect(result.first.reasons, contains('recentContext'));
    });
  });

  group('response ranking and safety', () {
    const engine = ConversationResponseEngine();
    final safe = OpenerLine(
      id: 'safe-kiss',
      japaneseText: 'キスは相性が出る気がする。',
      englishMeaning: 'I think a kiss says a lot about compatibility.',
      translations: const <String, String>{'ko': '키스에는 궁합이 드러나는 것 같아.'},
      category: LineCategory.kissing,
      tones: const <Tone>{Tone.flirty, Tone.romantic},
      boldness: ConversationBoldness.flirty,
      usageType: ConversationUsageType.statement,
      topics: const <String>{'kissing', 'compatibility'},
      manualOnly: true,
    );
    final explicit = OpenerLine(
      id: 'explicit-kiss',
      japaneseText: '露骨なキスの一言',
      englishMeaning: 'An explicit kissing reply.',
      translations: const <String, String>{'ko': '노골적인 키스 답변'},
      category: LineCategory.intimate,
      tones: const <Tone>{Tone.suggestive},
      boldness: ConversationBoldness.explicit,
      usageType: ConversationUsageType.statement,
      topics: const <String>{'kissing'},
      manualOnly: true,
    );
    final funny = OpenerLine(
      id: 'funny-kiss',
      japaneseText: 'キスにも面接が必要かも。',
      englishMeaning: 'Maybe kissing needs an interview first.',
      category: LineCategory.kissing,
      tones: const <Tone>{Tone.witty, Tone.humorous},
      boldness: ConversationBoldness.flirty,
      usageType: ConversationUsageType.comeback,
      topics: const <String>{'kissing'},
    );

    test('matches the incoming topic rather than the output language', () {
      final result = engine.suggest(
        transcript: '키스할 때 궁합이 중요하다고 생각해?',
        library: <OpenerLine>[safe, explicit],
        limit: 2,
      );
      expect(result.interpretation.language, DetectedLanguage.korean);
      expect(result.suggestions.first.line.id, 'safe-kiss');
    });

    test('explicit lines cannot leak without both opt-in and max boldness', () {
      final off = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, explicit],
        limit: 5,
      );
      expect(off.suggestions.map((item) => item.line.id),
          isNot(contains('explicit-kiss')));

      final on = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, explicit],
        preferences: const ConversationPreferences(
          tone: ConversationToneBias.bold,
          maxBoldness: ConversationBoldness.explicit,
          adultContentEnabled: true,
        ),
        limit: 5,
      );
      expect(on.suggestions.map((item) => item.line.id),
          contains('explicit-kiss'));
    });

    test('recent suggestions are rotated down', () {
      final result = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, explicit],
        preferences: const ConversationPreferences(
          maxBoldness: ConversationBoldness.explicit,
          adultContentEnabled: true,
          recentLineIds: <String>{'safe-kiss'},
        ),
        limit: 2,
      );
      expect(result.suggestions.first.line.id, 'explicit-kiss');
    });

    test('tone bias and response-shaped usage affect ordering', () {
      final result = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, funny],
        preferences: const ConversationPreferences(
          tone: ConversationToneBias.funny,
        ),
        limit: 2,
      );
      expect(result.suggestions.first.line.id, 'funny-kiss');
      expect(result.suggestions, hasLength(2));
    });

    test('low STT confidence falls back instead of over-specific ranking', () {
      final fallback = OpenerLine(
        id: 'seed-universal-10',
        japaneseText: '今日ここに来てよかった。',
        englishMeaning: 'I am glad I came here today.',
        tones: const <Tone>{Tone.friendly},
      );
      final result = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, funny, fallback],
        transcriptionConfidence: 0.2,
      );
      expect(result.lowRecognitionConfidence, isTrue);
      expect(result.usedSafeFallback, isTrue);
      expect(result.suggestions.first.line.id, 'seed-universal-10');
    });

    test('live results never exceed three cards', () {
      final lines = <OpenerLine>[
        safe,
        funny,
        for (var i = 0; i < 4; i++)
          OpenerLine(
            id: 'extra-$i',
            japaneseText: '短い返事$i',
            englishMeaning: 'Short reply $i',
            tones: const <Tone>{Tone.friendly},
            topics: const <String>{'kissing'},
          ),
      ];
      final result = engine.suggest(
        transcript: 'Do you like kissing?',
        library: lines,
      );
      expect(result.suggestions.length, lessThanOrEqualTo(3));
      expect(
        result.suggestions.map((item) => item.line.id).toSet().length,
        result.suggestions.length,
      );
    });
  });

  test('VAD stops only after actual speech followed by silence', () {
    final tracker = VoiceActivityTracker(
      silenceDuration: const Duration(seconds: 1),
      minimumSpeechDuration: Duration.zero,
      levelMargin: 3,
    );
    final start = DateTime.utc(2026, 1, 1);
    tracker.addLevel(1, start);
    expect(tracker.shouldStop(start.add(const Duration(seconds: 4))), isFalse);
    tracker.addLevel(8, start.add(const Duration(milliseconds: 100)));
    expect(tracker.shouldStop(start.add(const Duration(milliseconds: 900))),
        isFalse);
    expect(tracker.shouldStop(start.add(const Duration(milliseconds: 1200))),
        isTrue);
  });

  test('default recording windows are two seconds more forgiving', () {
    final tracker = VoiceActivityTracker();
    expect(tracker.silenceDuration, const Duration(milliseconds: 3400));
    expect(ConversationAssistController.noSpeechTimeout,
        const Duration(seconds: 10));
  });

  test('controller accepts partial/final transcript and keeps short history',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    addTearDown(controller.close);
    final reply = OpenerLine(
      id: 'reply',
      japaneseText: '週末はゆっくりする予定。',
      englishMeaning: 'I am planning a quiet weekend.',
      tones: const <Tone>{Tone.friendly},
    );

    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    recognition.result('週末は何をするの？', false, 0.4);
    expect(controller.transcript, contains('週末'));
    expect(controller.result, isNull);
    expect(controller.phase, ConversationAssistPhase.listening);
    recognition.result('週末は何をするの？', true, 0.9);
    await Future<void>.delayed(Duration.zero);

    expect(controller.phase, ConversationAssistPhase.suggestions);
    expect(controller.result, isNotNull);
    expect(controller.history, hasLength(1));
    expect(controller.feedback.last.kind, SuggestionFeedbackKind.shown);

    controller.acceptSuggestion('reply');
    expect(controller.feedback.last.kind, SuggestionFeedbackKind.accepted);
    expect(
      controller.feedbackFor('reply'),
      SuggestionFeedbackKind.accepted,
    );

    controller.dismissSuggestion('reply');
    expect(controller.feedback.last.kind, SuggestionFeedbackKind.dismissed);
    expect(
      controller.feedbackFor('reply'),
      SuggestionFeedbackKind.dismissed,
    );
  });

  test('controller starts, manually stops, and releases audio resources',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    expect(recognition.startCount, 1);
    expect(controller.isListening, isTrue);

    await controller.stop();
    expect(recognition.stopCount, 1);
    expect(controller.phase, ConversationAssistPhase.noSpeech);

    await controller.close();
    expect(recognition.disposeCount, 1);
  });
}

class FakeConversationRecognitionService
    implements ConversationRecognitionService {
  ConversationRecognitionCallbacks? callbacks;
  bool started = false;
  int startCount = 0;
  int stopCount = 0;
  int disposeCount = 0;

  @override
  bool get isSupported => true;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) async {
    this.callbacks = callbacks;
    return true;
  }

  @override
  Future<void> start({required ConversationInputLanguage language}) async {
    started = true;
    startCount++;
  }

  void result(String text, bool finalResult, double confidence) {
    callbacks!.onResult(text, finalResult, confidence);
  }

  @override
  Future<void> stop() async {
    started = false;
    stopCount++;
  }

  @override
  Future<void> cancel() async => started = false;

  @override
  Future<void> dispose() async {
    started = false;
    disposeCount++;
  }
}
