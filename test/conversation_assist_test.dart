import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencue/data/seed/conversation_seed_loader.dart';
import 'package:opencue/domain/enums/enums.dart';
import 'package:opencue/domain/models/app_settings.dart';
import 'package:opencue/domain/models/opener_line.dart';
import 'package:opencue/domain/speech/speech_controller.dart';
import 'package:opencue/domain/speech/speech_service.dart';

import '../lib/domain/conversation/conversation_assist_controller.dart';
import '../lib/domain/conversation/conversation_intent_catalog.dart';
import '../lib/domain/conversation/conversation_intent_matcher.dart';
import '../lib/domain/conversation/conversation_interpreter.dart';
import '../lib/domain/conversation/conversation_models.dart';
import '../lib/domain/conversation/conversation_recognition_service.dart';
import '../lib/domain/conversation/conversation_response_engine.dart';
import '../lib/domain/conversation/conversation_speech_log.dart';
import '../lib/domain/conversation/language_detector.dart';
import '../lib/domain/conversation/semantic_intent_classifier.dart';
import '../lib/domain/conversation/voice_activity_tracker.dart';

class FakeSemanticClassifier
    implements ConversationSemanticIntentClassifier {
  const FakeSemanticClassifier(this.intentId, this.confidence);

  final String intentId;
  final double confidence;

  @override
  Future<SemanticIntentClassification?> classify({
    required String transcript,
    required List<ConversationTurn> recentTurns,
  }) async =>
      SemanticIntentClassification(
        intentId: intentId,
        confidence: confidence,
      );
}

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

  test('Listen Mode Auto Speak is off by default and persists explicitly', () {
    expect(AppSettings.defaults.conversationAssistAutoSpeakEnabled, isFalse);
    final enabled = AppSettings.defaults.copyWith(
      conversationAssistAutoSpeakEnabled: true,
    );
    expect(
      AppSettings.fromJson(enabled.toJson())
          .conversationAssistAutoSpeakEnabled,
      isTrue,
    );
    expect(
      AppSettings.fromStringMap(enabled.toStringMap())
          .conversationAssistAutoSpeakEnabled,
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

    test('ships the unified maintainable high-value intent catalog', () {
      expect(conversationIntentCatalog.length, greaterThanOrEqualTo(200));
      expect(
        conversationIntentCatalog.map((intent) => intent.id).toSet().length,
        conversationIntentCatalog.length,
      );
      expect(
        conversationIntentCatalog.every((intent) =>
            intent.examples.length >= 2 && intent.responseHints.length >= 3),
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
          'relationship_status');
      expect(matcher.match('モテそう').first.id, 'tease_popular');
      expect(matcher.match('今週末何してる？').first.id,
          'ask_weekend_plans');
      expect(matcher.match('また飲もう').first.id, 'invite_drink_again');
    });

    test('actionable question outranks a passive compliment', () {
      final result = interpreter.interpret(
        '日本語上手ですね。日本にどのくらいいるんですか？',
      );
      expect(result.primaryIntentId, 'time_in_japan');
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
        semanticIntentId: 'ask_kiss_preference',
        semanticConfidence: 0.9,
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

    test('recent penalties do not bypass the fixed reel slots', () {
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
      expect(result.suggestions.first.line.id, 'safe-kiss');
      expect(result.suggestions.first.slot, ConversationReelSlot.standard);
      expect(result.suggestions.map((item) => item.line.id),
          contains('explicit-kiss'));
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
      expect(result.suggestions.first.line.id, 'safe-kiss');
      expect(result.suggestions[1].line.id, 'funny-kiss');
      expect(result.suggestions[1].slot, ConversationReelSlot.funny);
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

    test('zero STT confidence means unavailable, not low confidence', () {
      final result = engine.suggest(
        transcript: 'Do you like kissing?',
        library: <OpenerLine>[safe, funny],
        transcriptionConfidence: 0,
      );
      expect(result.lowRecognitionConfidence, isFalse);
      expect(result.interpretation.primaryIntent, isNotNull);
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

  group('finalized utterance pipeline', () {
    final timeReply = OpenerLine(
      id: 'time-reply',
      japaneseText: 'もう三年くらいだよ。',
      englishMeaning: 'About three years now.',
      tones: const <Tone>{Tone.friendly},
      usageType: ConversationUsageType.statement,
      topics: const <String>{'travel', 'japanese'},
    );
    final relationshipReply = OpenerLine(
      id: 'relationship-reply',
      japaneseText: '今はいないですよ。',
      englishMeaning: 'I am not seeing anyone right now.',
      tones: const <Tone>{Tone.friendly},
      usageType: ConversationUsageType.statement,
      topics: const <String>{'relationships', 'dating'},
    );

    test('Japan-duration variants automatically replace cue state', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      final library = <OpenerLine>[timeReply, relationshipReply];

      final first = await controller.onUtteranceFinalized(
        '日本に来てどのくらいですか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(first, isTrue);
      expect(controller.result!.interpretation.primaryIntentId,
          'time_in_japan');
      expect(controller.result!.suggestions, isNotEmpty);

      final second = await controller.onUtteranceFinalized(
        '日本何年目ですか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(second, isTrue);
      expect(controller.result!.interpretation.primaryIntentId,
          'time_in_japan');
      expect(controller.cueRevision, 2);
    });

    test('relationship variants select relationship response family',
        () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      final library = <OpenerLine>[timeReply, relationshipReply];

      await controller.onUtteranceFinalized(
        '彼女いますか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(controller.result!.interpretation.primaryIntentId,
          'relationship_status');
      expect(controller.result!.suggestions.first.line.id,
          'relationship-reply');

      await controller.onUtteranceFinalized(
        '今フリー？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(controller.result!.interpretation.primaryIntentId,
          'single_status');
    });

    test('installed library contains speakable relationship replies', () {
      final library = const ConversationSeedLoader().load(
        createdAt: DateTime.utc(2026),
      );
      final result = const ConversationResponseEngine().suggest(
        transcript: '彼女いるんですか？',
        library: library,
      );
      expect(result.interpretation.primaryIntentId, 'relationship_status');
      expect(
        result.suggestions.map((item) => item.line.japaneseText),
        contains('今はいないですよ。'),
      );
    });

    test('no-action speech preserves the existing cue set', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      final library = <OpenerLine>[timeReply, relationshipReply];
      await controller.onUtteranceFinalized(
        '彼女いますか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      final previous = controller.result;
      final revision = controller.cueRevision;

      final updated = await controller.onUtteranceFinalized(
        'ありがとう',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(updated, isFalse);
      expect(controller.result, same(previous));
      expect(controller.cueRevision, revision);
      expect(controller.diagnostics!.intentId, 'no_action');
      expect(controller.diagnostics!.action,
          CueUpdateAction.preservedIrrelevant);
    });

    test('duplicate final results update cues only once', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      final library = <OpenerLine>[relationshipReply];
      await controller.onUtteranceFinalized(
        '彼女いますか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      final firstRevision = controller.cueRevision;
      final duplicate = await controller.onUtteranceFinalized(
        '彼女いますか？',
        library: library,
        preferences: const ConversationPreferences(),
      );
      expect(duplicate, isFalse);
      expect(controller.cueRevision, firstRevision);
      expect(controller.diagnostics!.action,
          CueUpdateAction.preservedDuplicate);
    });

    test('manual submission uses the finalized utterance pipeline', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
      );
      addTearDown(controller.dispose);
      await controller.onUtteranceFinalized(
        '今フリー？',
        library: <OpenerLine>[relationshipReply],
        preferences: const ConversationPreferences(),
        source: FinalizedUtteranceSource.manual,
      );
      expect(controller.result!.interpretation.primaryIntentId,
          'single_status');
      expect(controller.diagnostics!.source,
          FinalizedUtteranceSource.manual);
      expect(controller.diagnostics!.action, CueUpdateAction.updated);
      expect(controller.diagnostics!.matcherReasons, isNotEmpty);
      expect(controller.diagnostics!.responseHints, contains('single_status'));
      expect(controller.diagnostics!.topResponseScores, isNotEmpty);
    });

    test('semantic fallback can supply a structured catalog intent', () async {
      final controller = ConversationAssistController(
        recognition: const NullConversationRecognitionService(),
        semanticClassifier: const FakeSemanticClassifier(
          'relationship_status',
          0.91,
        ),
      );
      addTearDown(controller.dispose);
      await controller.onUtteranceFinalized(
        '交際状況を教えて',
        library: <OpenerLine>[relationshipReply],
        preferences: const ConversationPreferences(),
      );
      expect(controller.result!.interpretation.primaryIntentId,
          'relationship_status');
      expect(controller.diagnostics!.matcher,
          ConversationMatcherKind.semantic);
    });

    test('partial STT updates call the response engine only after finalization',
        () async {
      final recognition = FakeConversationRecognitionService();
      final provider = CountingSuggestionProvider();
      final controller = ConversationAssistController(
        recognition: recognition,
        responseEngine: provider,
      );
      addTearDown(controller.dispose);
      await controller.start(
        library: <OpenerLine>[relationshipReply],
        preferences: const ConversationPreferences(),
      );

      recognition.result('彼女', false, 0);
      recognition.result('彼女いる', false, 0);
      recognition.result('彼女いるん', false, 0);
      expect(provider.callCount, 0);
      recognition.result('彼女いるんですか', true, 0);
      await Future<void>.delayed(const Duration(milliseconds: 180));

      expect(provider.callCount, 1);
      expect(controller.cueRevision, 1);
      expect(controller.result!.interpretation.primaryIntentId,
          'relationship_status');
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
    tracker.addLevel(8, start.add(const Duration(milliseconds: 220)));
    expect(tracker.shouldStop(start.add(const Duration(milliseconds: 900))),
        isFalse);
    expect(tracker.shouldStop(start.add(const Duration(milliseconds: 1300))),
        isTrue);
  });

  test('default VAD uses a natural pause and transcript pre-roll', () {
    final tracker = VoiceActivityTracker();
    expect(tracker.silenceDuration, const Duration(milliseconds: 700));
    expect(tracker.preRollDuration, const Duration(milliseconds: 300));
  });

  test('VAD ignores an isolated ambient spike', () {
    final tracker = VoiceActivityTracker(
      speechDebounce: const Duration(milliseconds: 120),
    );
    final start = DateTime.utc(2026, 1, 1);
    tracker.addLevel(1, start);
    tracker.addLevel(12, start.add(const Duration(milliseconds: 20)));
    tracker.addLevel(1, start.add(const Duration(milliseconds: 70)));
    expect(tracker.heardSpeech, isFalse);
    expect(
      tracker.shouldStop(start.add(const Duration(seconds: 2))),
      isFalse,
    );
  });

  test('controller VAD detects speech, ends on silence, and resumes',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(
      recognition: recognition,
      voiceActivityTracker: VoiceActivityTracker(
        silenceDuration: const Duration(milliseconds: 25),
        minimumSpeechDuration: Duration.zero,
        speechDebounce: Duration.zero,
      ),
      vadPollInterval: const Duration(milliseconds: 5),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'vad-reply',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    recognition.sound(0);
    recognition.result('彼女いますか？', false, 0.8);
    expect(
      controller.speechState,
      ConversationSpeechState.capturingUtterance,
    );

    await Future<void>.delayed(const Duration(milliseconds: 90));

    expect(recognition.stopCount, 1);
    expect(controller.result, isNotNull);
    expect(recognition.startCount, 2);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('Listen button transition lock rejects duplicate Start and Stop',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
      listenButtonDebounce: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);

    final firstStart = controller.toggleListenMode(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    final duplicateStart = controller.toggleListenMode(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await Future.wait(<Future<void>>[firstStart, duplicateStart]);
    expect(recognition.startCount, 1);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    final firstStop = controller.toggleListenMode(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    final duplicateStop = controller.toggleListenMode(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await Future.wait(<Future<void>>[firstStop, duplicateStop]);
    expect(recognition.cancelCount, 1);
    expect(controller.listenModeActive, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    await controller.toggleListenMode(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    expect(recognition.startCount, 2);
    expect(
      logs.where((line) => line.contains('duplicate_press_ignored')),
      hasLength(2),
    );
  });

  test('imperfect Korean cute transcript still produces a response',
      () async {
    final controller = ConversationAssistController(
      recognition: const NullConversationRecognitionService(),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'korean-cute-reply',
      japaneseText: 'ありがとうございます。',
      translations: const <String, String>{'ko': '감사해요.'},
      topics: const <String>{
        'compliment_cute',
        'reaction_cute',
        'compliments',
        'appearance',
      },
    );

    final updated = await controller.onUtteranceFinalized(
      '여워 여귀여워',
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );

    expect(updated, isTrue);
    expect(controller.result, isNotNull);
    expect(controller.result!.suggestions.first.line.id, reply.id);
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
    recognition.result('今週末何してる？', false, 0.4);
    expect(controller.transcript, contains('週末'));
    expect(controller.result, isNull);
    expect(controller.phase, ConversationAssistPhase.capturingUtterance);
    recognition.result('今週末何してる？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    expect(controller.phase, ConversationAssistPhase.starting);
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
    expect(recognition.stopCount, 0);
    expect(recognition.cancelCount, 1);
    expect(controller.phase, ConversationAssistPhase.idle);
    expect(controller.speechState, ConversationSpeechState.idle);

    await controller.close();
    expect(recognition.disposeCount, 1);
  });

  test('Waiting for speech appears only after native audio activity',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );

    expect(controller.speechState, ConversationSpeechState.starting);
    expect(controller.phase, ConversationAssistPhase.starting);
    recognition.sound(-2);
    expect(controller.speechState, ConversationSpeechState.readyForSpeech);
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
    recognition.result('彼女', false, 0.4);
    expect(
      controller.speechState,
      ConversationSpeechState.capturingUtterance,
    );
    expect(controller.phase, ConversationAssistPhase.capturingUtterance);
  });

  test('startup watchdog cancels a recognizer with no native audio progress',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
      startupWatchdogDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await Future<void>.delayed(const Duration(milliseconds: 35));

    expect(controller.speechState, ConversationSpeechState.idle);
    expect(controller.phase, ConversationAssistPhase.error);
    expect(recognition.cancelCount, 1);
    expect(
      logs.any((line) => line.contains('SPEECH_RECOGNIZER_STALLED')),
      isTrue,
    );
  });

  test('Stop immediately cancels STARTING, READY, and SPEECH states',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);

    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await controller.stop();
    expect(controller.speechState, ConversationSpeechState.idle);

    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.sound(-2);
    await controller.stop();
    expect(controller.speechState, ConversationSpeechState.idle);

    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.sound(-2);
    recognition.result('話しています', false, 0.5);
    await controller.stop();
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(recognition.cancelCount, 3);
    expect(recognition.startCount, 3);
  });

  test('Stop during PROCESSING invalidates the response pipeline', () async {
    final recognition = FakeConversationRecognitionService();
    final classifier = DelayedSemanticClassifier();
    final controller = ConversationAssistController(
      recognition: recognition,
      semanticClassifier: classifier,
    );
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.result('分類を待つ発話', true, 0.7);
    await Future<void>.delayed(Duration.zero);
    expect(controller.speechState, ConversationSpeechState.processing);

    await controller.stop();
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(controller.phase, ConversationAssistPhase.idle);
    classifier.complete('greeting', 0.9);
    await Future<void>.delayed(Duration.zero);
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(controller.listenModeActive, isFalse);
    expect(recognition.startCount, 1);
  });

  test('an empty platform terminal callback quietly resumes persistent mode',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.status('done');
    await Future<void>.delayed(Duration.zero);
    expect(controller.listenModeActive, isTrue);
    expect(recognition.startCount, 2);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('repeated taps while non-idle cannot create overlapping sessions',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    expect(recognition.startCount, 1);
    expect(controller.activeRecognitionSessionId, 1);

    recognition.status('done');
    await Future<void>.delayed(Duration.zero);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    expect(recognition.startCount, 2);
    expect(controller.activeRecognitionSessionId, 2);
  });

  test('late Android error_client from cancel is ignored after Stop',
      () async {
    final recognition = FakeConversationRecognitionService()
      ..errorClientOnCancel = true;
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'error-client-reply',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    await controller.stop();

    expect(controller.errorMessage, isNull);
    expect(controller.listenModeActive, isFalse);
    expect(controller.phase, ConversationAssistPhase.idle);
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(recognition.startCount, 1);
    expect(recognition.cancelCount, 1);
  });

  test('a spontaneous Android error_client never auto-retries', () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_client', permanent: true);
    expect(controller.listenModeActive, isTrue);
    expect(controller.errorMessage, 'error_client');
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(recognition.startCount, 1);
    expect(controller.speechState, ConversationSpeechState.idle);
  });

  test('Android error_busy returns to idle without a hidden retry',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_busy', permanent: true);
    recognition.status('notListening');
    await Future<void>.delayed(const Duration(milliseconds: 900));
    expect(recognition.startCount, 1);
    expect(controller.listenModeActive, isTrue);
    expect(controller.errorMessage, 'error_busy');
    expect(controller.speechState, ConversationSpeechState.idle);
  });

  test('Android network errors return to idle without mode switching',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_network', permanent: false, platformCode: 2);
    recognition.status('notListening');
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    expect(recognition.startCount, 1);
    expect(controller.listenModeActive, isTrue);
    expect(controller.errorMessage, 'error_network');
    expect(controller.speechState, ConversationSpeechState.idle);
  });

  test('an established turn recovers once from Android error_busy',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(
      recognition: recognition,
      rearmRetryDelay: const Duration(milliseconds: 5),
    );
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.sound(0);
    recognition.error('error_busy', permanent: true, platformCode: 8);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(controller.listenModeActive, isTrue);
    expect(recognition.startCount, 2);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('no-match and permission errors are terminal and manually retryable',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_no_match', permanent: false, platformCode: 7);
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(recognition.startCount, 1);

    await controller.stop();
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error(
      'error_insufficient_permissions',
      permanent: true,
      platformCode: 9,
    );
    expect(controller.phase, ConversationAssistPhase.permissionDenied);
    expect(controller.speechState, ConversationSpeechState.idle);
    expect(recognition.startCount, 2);
  });

  test('Auto Speak suppresses self-voice and resumes recognition', () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService()..hold();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      postTtsAudioReleaseDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'relationship-auto',
      japaneseText: '今はいないですよ。🙂',
      englishMeaning: 'Not right now.',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
    );
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(controller.phase, ConversationAssistPhase.speaking);
    expect(controller.recognitionSuppressed, isTrue);
    recognition.result('今はいないですよ', true, 0.99);
    expect(controller.cueRevision, 1);

    speechService.finish();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(speechService.spoken, <String>['今はいないですよ。']);
    expect(controller.listenModeActive, isTrue);
    expect(controller.recognitionSuppressed, isFalse);
    expect(recognition.startCount, 2);
    expect(controller.speechState, ConversationSpeechState.starting);
    expect(
      controller.history.any(
        (turn) => turn.speaker == ConversationSpeaker.user,
      ),
      isTrue,
    );
  });

  test('Stop during post-TTS rearm delay prevents microphone restart',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final speechService = ControlledSpeechService()..hold();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
      postTtsAudioReleaseDelay: const Duration(milliseconds: 80),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'stop-during-rearm',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
    );
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(controller.speechState, ConversationSpeechState.ttsPlaying);
    speechService.finish();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(controller.speechState, ConversationSpeechState.resuming);
    await controller.stop();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(controller.listenModeActive, isFalse);
    expect(recognition.startCount, 1);
    expect(
      logs.any((line) => line.contains('event=pending_rearm_cancelled')),
      isTrue,
    );
    expect(
      logs.any((line) => line.contains('event=rearm_cancelled_before_start')),
      isTrue,
    );
  });

  test('a failed rearm start gets one bounded retry without disabling mode',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(
      recognition: recognition,
      rearmRetryDelay: const Duration(milliseconds: 5),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'bounded-rearm',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    recognition.failStartsRemaining = 1;
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(recognition.startCount, 3);
    expect(controller.listenModeActive, isTrue);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('manual response playback is rejected while recognition owns audio',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService()..hold();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      postTtsAudioReleaseDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    final line = OpenerLine(
      id: 'manual-playback',
      japaneseText: 'そうですね。🙂',
    );
    await controller.start(
      library: <OpenerLine>[line],
      preferences: const ConversationPreferences(),
      speechController: speech,
    );
    final playback = speech.toggleJapanese(
      lineId: line.id,
      japaneseText: line.japaneseText,
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.recognitionSuppressed, isFalse);
    expect(recognition.cancelCount, 0);
    expect(speechService.spoken, isEmpty);
    expect(controller.cueRevision, 0);

    await playback;
    expect(controller.recognitionSuppressed, isFalse);
    expect(recognition.startCount, 1);
  });

  test('Auto Speak off never invokes TTS and resumes persistent listening',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      postTtsAudioReleaseDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'relationship-silent',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
      speechController: speech,
    );
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(speechService.spoken, isEmpty);
    expect(recognition.startCount, 2);
    expect(controller.result, isNotNull);
    expect(controller.phase, ConversationAssistPhase.starting);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('TTS failure clears playback ownership and safely resumes listening',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService()..throwOnSpeak = true;
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'tts-failure-reply',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
    );
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(speech.lastError, contains('TTS test failure'));
    expect(controller.speechState, ConversationSpeechState.starting);
    expect(controller.recognitionSuppressed, isFalse);
    expect(recognition.startCount, 2);
  });

  test('processing watchdog invalidates a hung turn and resumes once',
      () async {
    final recognition = FakeConversationRecognitionService();
    final classifier = DelayedSemanticClassifier();
    final logs = <String>[];
    final controller = ConversationAssistController(
      recognition: recognition,
      semanticClassifier: classifier,
      processingTimeoutDuration: const Duration(milliseconds: 25),
      logger: ConversationSpeechLogger(sink: logs.add),
    );
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
      autoSpeak: true,
    );

    recognition.result('分類結果が返らない発話', true, 0.8);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(logs.any((line) => line.contains('PROCESSING_TIMEOUT')), isTrue);
    expect(controller.speechState, ConversationSpeechState.starting);
    expect(recognition.startCount, 2);
    classifier.complete('greeting', 0.9);
    await Future<void>.delayed(Duration.zero);
    expect(recognition.startCount, 2);
  });

  test('Auto Speak setting changes apply without recreating controller',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      postTtsAudioReleaseDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    final lines = List<OpenerLine>.generate(
      12,
      (index) => OpenerLine(
        id: 'toggle-reply-$index',
        japaneseText: '今はいないですよ。$index',
        topics: const <String>{'relationship_status'},
      ),
    );
    await controller.start(
      library: lines,
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
    );
    recognition.result('彼女はいますか？ 一回目', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(speechService.spoken, hasLength(1));
    expect(recognition.startCount, 2);

    controller.setAutoSpeak(false);
    recognition.result('彼女はいますか？ 二回目', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(speechService.spoken, hasLength(1));
    expect(controller.speechState, ConversationSpeechState.starting);
    expect(recognition.startCount, 3);

    controller.setAutoSpeak(true);
    recognition.result('彼女はいますか？ 三回目', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(speechService.spoken, hasLength(2));
    expect(recognition.startCount, 4);
  });

  test('10 consecutive primary TTS turns each speak once and resume',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      postTtsAudioReleaseDelay: Duration.zero,
    );
    addTearDown(controller.dispose);
    final lines = List<OpenerLine>.generate(
      40,
      (index) => OpenerLine(
        id: 'cycle-reply-$index',
        japaneseText: '今はいないですよ。$index',
        topics: const <String>{'relationship_status'},
      ),
    );
    await controller.start(
      library: lines,
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
    );

    for (var turn = 0; turn < 10; turn++) {
      recognition.result('彼女はいますか？ turn $turn', true, 0.9);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(speechService.spoken, hasLength(turn + 1));
      expect(recognition.startCount, turn + 2);
      expect(controller.listenModeActive, isTrue);
    }
    expect(speechService.turnIds.whereType<int>().toSet(), hasLength(10));
    expect(speechService.utteranceIds.whereType<int>().toSet(), hasLength(10));
  });

  test('primary response is published before same-turn variants', () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    final lengths = <int>[];
    controller.addListener(() {
      final length = controller.result?.suggestions.length;
      if (length != null && (lengths.isEmpty || lengths.last != length)) {
        lengths.add(length);
      }
    });
    final lines = <OpenerLine>[
      OpenerLine(
        id: 'staged-standard',
        japaneseText: '今はいないですよ。',
        topics: const <String>{'relationship_status'},
        tones: const <Tone>{Tone.friendly},
      ),
      OpenerLine(
        id: 'staged-funny',
        japaneseText: '今は面接中ですね。',
        topics: const <String>{'relationship_status'},
        tones: const <Tone>{Tone.witty, Tone.humorous},
      ),
      OpenerLine(
        id: 'staged-flirty',
        japaneseText: '今はいないけど、立候補します？',
        topics: const <String>{'relationship_status'},
        tones: const <Tone>{Tone.flirty},
      ),
    ];
    await controller.start(
      library: lines,
      preferences: const ConversationPreferences(),
    );
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(lengths, contains(1));
    expect(controller.result!.suggestions.length, greaterThan(1));
    expect(
      controller.result!.suggestions
          .map((item) => item.line.topics)
          .every((topics) => topics.contains('relationship_status')),
      isTrue,
    );
  });

  test('Korean output mode Auto Speaks Hangul and resumes listening',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'relationship-korean',
      japaneseText: '今はいないですよ。',
      translations: const <String, String>{'ko': '지금은 없어요.🙂'},
      topics: const <String>{'relationship_status'},
    );
    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
      speechController: speech,
      autoSpeak: true,
      outputLanguageMode: LanguageMode.korean,
    );
    recognition.result('지금 여자 친구 있어요?', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(speechService.spoken, <String>['지금은 없어요.']);
    expect(speechService.languages, <String>[SpeechController.koreanLocale]);
    expect(recognition.languages.last, ConversationInputLanguage.korean);
    expect(logs.any((line) => line.contains('language=ko-KR')), isTrue);
    expect(logs.any((line) => line.contains('event=final_transcript')), isTrue);
    expect(
      logs.any((line) => line.contains('event=response_generation_complete')),
      isTrue,
    );
    expect(logs.any((line) => line.contains('event=tts_invoked')), isTrue);
    expect(recognition.startCount, 2);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('one Start supports ten automatic turns with no extra button press',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'ten-cycle-reply',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );

    await controller.start(
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    for (var cycle = 1; cycle <= 10; cycle++) {
      expect(controller.activeRecognitionSessionId, cycle);
      recognition.result('彼女いますか？ $cycle', true, 0.9);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.speechState, ConversationSpeechState.starting);
      expect(controller.result, isNotNull);
    }

    expect(recognition.startCount, 11);
    expect(recognition.stopCount, 0);
    expect(recognition.cancelCount, 0);
    expect(
      recognition.sessionIds,
      List<int>.generate(11, (index) => index + 1),
    );
    expect(
      logs.where((line) => line.contains('event=user_pressed_listen')),
      hasLength(1),
    );
  });

  test('English mode supports five turns after one Start', () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    controller.setInputLanguage(ConversationInputLanguage.english);
    final replies = List<OpenerLine>.generate(
      12,
      (index) => OpenerLine(
        id: 'english-cycle-$index',
        japaneseText: '日本が好きだから来ました。$index',
        englishMeaning: 'I came because I like Japan.',
        topics: const <String>{'ask_reason_japan'},
      ),
    );

    await controller.start(
      library: replies,
      preferences: const ConversationPreferences(),
    );
    for (var cycle = 1; cycle <= 5; cycle++) {
      recognition.result('Why did you come to Japan? $cycle', true, 0.9);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.result, isNotNull);
      expect(controller.listenModeActive, isTrue);
      expect(recognition.startCount, cycle + 1);
    }
  });

  test('a late callback from an old session cannot mutate a newer session',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.status('done', sessionId: 1);
    await Future<void>.delayed(Duration.zero);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );

    recognition.result('古い結果', true, 0.9, sessionId: 1);
    expect(controller.activeRecognitionSessionId, 2);
    expect(controller.transcript, isEmpty);
    expect(controller.speechState, ConversationSpeechState.starting);
  });

  test('recognition language changes apply to the next manual session',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    controller.setInputLanguage(ConversationInputLanguage.japanese);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    await controller.stop();
    controller.setInputLanguage(ConversationInputLanguage.korean);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    expect(
      recognition.languages,
      <ConversationInputLanguage>[
        ConversationInputLanguage.japanese,
        ConversationInputLanguage.korean,
      ],
    );
  });

  test('app Japanese, Korean, and Both modes configure the next session',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);

    for (final mode in <LanguageMode>[
      LanguageMode.japanese,
      LanguageMode.korean,
      LanguageMode.both,
    ]) {
      await controller.start(
        library: const <OpenerLine>[],
        preferences: const ConversationPreferences(),
        outputLanguageMode: mode,
      );
      await controller.stop();
    }

    expect(
      recognition.languages,
      <ConversationInputLanguage>[
        ConversationInputLanguage.japanese,
        ConversationInputLanguage.korean,
        ConversationInputLanguage.both,
      ],
    );
  });

  test('Auto JP/KR logs its platform limitation without fake confidence',
      () async {
    final recognition = FakeConversationRecognitionService();
    final logs = <String>[];
    final controller = ConversationAssistController(
      recognition: recognition,
      logger: ConversationSpeechLogger(sink: logs.add),
    );
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
      outputLanguageMode: LanguageMode.both,
    );

    recognition.result('귀여워요', true, 0);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final autoLog = logs.firstWhere(
      (line) => line.contains('[AutoLanguage]'),
    );
    expect(autoLog, contains('detectedTranscriptScript=korean'));
    expect(autoLog, contains('confidence=unavailable'));
    expect(autoLog, contains('fallbackUsed=false'));
    expect(autoLog, contains('fallbackAvailable=false'));
    expect(autoLog, contains('raw_audio_not_retained_by_speech_to_text'));
  });

  test('a short follow-up reuses recent incoming intent context', () async {
    final controller = ConversationAssistController(
      recognition: const NullConversationRecognitionService(),
    );
    addTearDown(controller.dispose);
    final reply = OpenerLine(
      id: 'time-context',
      japaneseText: 'もう三年くらいだよ。',
      topics: const <String>{'time_in_japan'},
    );
    await controller.onUtteranceFinalized(
      '日本に来てどのくらいですか？',
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    final updated = await controller.onUtteranceFinalized(
      'それで？',
      library: <OpenerLine>[reply],
      preferences: const ConversationPreferences(),
    );
    expect(updated, isTrue);
    expect(controller.activeIntentId, 'time_in_japan');
    expect(controller.diagnostics!.matcher,
        ConversationMatcherKind.contextual);
  });

  test('a stale semantic result cannot overwrite a newer turn', () async {
    final classifier = DelayedSemanticClassifier();
    final controller = ConversationAssistController(
      recognition: const NullConversationRecognitionService(),
      semanticClassifier: classifier,
    );
    addTearDown(controller.dispose);
    final relationship = OpenerLine(
      id: 'stale-relationship',
      japaneseText: '今はいないですよ。',
      topics: const <String>{'relationship_status'},
    );
    final time = OpenerLine(
      id: 'fresh-time',
      japaneseText: 'もう三年くらいだよ。',
      topics: const <String>{'time_in_japan'},
    );
    final library = <OpenerLine>[relationship, time];
    final stale = controller.onUtteranceFinalized(
      '交際状況を教えて',
      library: library,
      preferences: const ConversationPreferences(),
    );
    await Future<void>.delayed(Duration.zero);
    await controller.onUtteranceFinalized(
      '日本何年目ですか？',
      library: library,
      preferences: const ConversationPreferences(),
    );
    classifier.complete('relationship_status', 0.95);
    await stale;
    expect(controller.activeIntentId, 'time_in_japan');
    expect(controller.result!.suggestions.first.line.id, 'fresh-time');
  });
}

class FakeConversationRecognitionService
    implements ConversationRecognitionService {
  ConversationRecognitionCallbacks? callbacks;
  bool started = false;
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  int disposeCount = 0;
  int failStartsRemaining = 0;
  bool errorClientOnCancel = false;
  int? currentSessionId;
  final List<int> sessionIds = <int>[];
  final List<ConversationInputLanguage> languages =
      <ConversationInputLanguage>[];

  @override
  bool get isSupported => true;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) async {
    this.callbacks = callbacks;
    return true;
  }

  @override
  Future<ConversationRecognitionStartInfo> start({
    required int sessionId,
    required ConversationInputLanguage language,
  }) async {
    started = true;
    currentSessionId = sessionId;
    startCount++;
    sessionIds.add(sessionId);
    languages.add(language);
    if (failStartsRemaining > 0) {
      failStartsRemaining--;
      currentSessionId = null;
      throw StateError('simulated recognizer busy during rearm');
    }
    callbacks!.onStatus(sessionId, 'listening');
    return ConversationRecognitionStartInfo(
      requestedLanguage: language,
      localeId: switch (language) {
        ConversationInputLanguage.japanese => 'ja-JP',
        ConversationInputLanguage.korean => 'ko-KR',
        ConversationInputLanguage.english => 'en-US',
        ConversationInputLanguage.both => 'ja-JP',
        ConversationInputLanguage.automatic => 'en-US',
      },
      strategy: language == ConversationInputLanguage.both
          ? 'both_safe_fallback_ja-JP'
          : 'test_explicit',
    );
  }

  void sound(double level, {int? sessionId}) =>
      callbacks!.onSoundLevel(sessionId ?? currentSessionId!, level);

  void result(
    String text,
    bool finalResult,
    double confidence, {
    int? sessionId,
  }) {
    final resolvedSessionId = sessionId ?? currentSessionId!;
    callbacks!.onResult(
      resolvedSessionId,
      text,
      finalResult,
      confidence,
    );
    if (finalResult) callbacks!.onStatus(resolvedSessionId, 'done');
  }

  void status(String status, {int? sessionId}) =>
      callbacks!.onStatus(sessionId ?? currentSessionId!, status);

  void error(
    String message, {
    required bool permanent,
    int? sessionId,
    int? platformCode,
  }) =>
      callbacks!.onError(
        sessionId ?? currentSessionId!,
        message,
        permanent: permanent,
        platformCode: platformCode,
      );

  @override
  Future<void> stop({required int sessionId}) async {
    started = false;
    stopCount++;
    callbacks!.onStatus(sessionId, 'done');
  }

  @override
  Future<void> cancel({required int sessionId}) async {
    started = false;
    cancelCount++;
    if (errorClientOnCancel) {
      callbacks!.onError(
        sessionId,
        'error_client',
        permanent: true,
        platformCode: 5,
      );
    }
  }

  @override
  Future<void> dispose() async {
    started = false;
    disposeCount++;
  }
}

class ControlledSpeechService implements SpeechService {
  final List<String> spoken = <String>[];
  final List<String> languages = <String>[];
  final List<int?> turnIds = <int?>[];
  final List<int?> utteranceIds = <int?>[];
  Completer<void>? _gate;
  bool throwOnSpeak = false;

  @override
  bool get isSupported => true;

  void hold() => _gate = Completer<void>();

  void finish() {
    _gate?.complete();
    _gate = null;
  }

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => true;

  @override
  Future<void> speak(
    String text, {
    required String languageCode,
    double rate = 0.5,
    int? turnId,
    int? utteranceId,
  }) async {
    spoken.add(text);
    languages.add(languageCode);
    turnIds.add(turnId);
    utteranceIds.add(utteranceId);
    if (throwOnSpeak) throw StateError('TTS test failure');
    final gate = _gate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class DelayedSemanticClassifier
    implements ConversationSemanticIntentClassifier {
  final Completer<SemanticIntentClassification?> _result =
      Completer<SemanticIntentClassification?>();

  void complete(String intentId, double confidence) => _result.complete(
        SemanticIntentClassification(
          intentId: intentId,
          confidence: confidence,
        ),
      );

  @override
  Future<SemanticIntentClassification?> classify({
    required String transcript,
    required List<ConversationTurn> recentTurns,
  }) =>
      _result.future;
}

class CountingSuggestionProvider implements ConversationSuggestionProvider {
  final ConversationResponseEngine _delegate =
      const ConversationResponseEngine();
  int callCount = 0;

  @override
  ConversationSuggestionResult suggest({
    required String transcript,
    required List<OpenerLine> library,
    ConversationPreferences preferences = const ConversationPreferences(),
    List<ConversationTurn> history = const <ConversationTurn>[],
    int limit = 3,
    double? transcriptionConfidence,
    String? semanticIntentId,
    double? semanticConfidence,
    String? lockedIntentId,
    Set<String> excludedLineIds = const <String>{},
    bool moreGeneration = false,
    ConversationInterpretation? activeInterpretation,
  }) {
    callCount++;
    return _delegate.suggest(
      transcript: transcript,
      library: library,
      preferences: preferences,
      history: history,
      limit: limit,
      transcriptionConfidence: transcriptionConfidence,
      semanticIntentId: semanticIntentId,
      semanticConfidence: semanticConfidence,
      lockedIntentId: lockedIntentId,
      excludedLineIds: excludedLineIds,
      moreGeneration: moreGeneration,
      activeInterpretation: activeInterpretation,
    );
  }
}
