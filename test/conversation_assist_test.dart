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
    expect(controller.phase, ConversationAssistPhase.hearingSpeech);
    recognition.result('今週末何してる？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 180));

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
    expect(controller.phase, ConversationAssistPhase.idle);

    await controller.close();
    expect(recognition.disposeCount, 1);
  });

  test('an idle platform recognition window restarts without leaving mode',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.status('done');
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(controller.listenModeActive, isTrue);
    expect(recognition.startCount, 2);
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
  });

  test('Android error_client from an intentional stop is ignored', () async {
    final recognition = FakeConversationRecognitionService()
      ..errorClientOnStop = true;
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
    recognition.result('彼女いますか？', true, 0.9);
    await Future<void>.delayed(const Duration(milliseconds: 320));

    expect(controller.errorMessage, isNull);
    expect(controller.listenModeActive, isTrue);
    expect(controller.result, isNotNull);
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
    expect(recognition.startCount, 2);
  });

  test('a spontaneous Android error_client gets a bounded retry', () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_client', permanent: true);
    expect(controller.listenModeActive, isTrue);
    expect(controller.errorMessage, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(recognition.startCount, 2);
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
  });

  test('Android error_busy waits for native release before retrying',
      () async {
    final recognition = FakeConversationRecognitionService();
    final controller = ConversationAssistController(recognition: recognition);
    addTearDown(controller.dispose);
    await controller.start(
      library: const <OpenerLine>[],
      preferences: const ConversationPreferences(),
    );
    recognition.error('error_busy', permanent: true);
    // Android normally follows the error with notListening. That callback
    // must not shorten the busy-specific cooldown.
    recognition.status('notListening');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(recognition.startCount, 1);
    expect(controller.listenModeActive, isTrue);
    expect(controller.errorMessage, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 560));
    expect(recognition.startCount, 2);
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
  });

  test('Auto Speak suppresses self-voice and resumes recognition', () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService()..hold();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(recognition: recognition);
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
    expect(
      controller.history.any(
        (turn) => turn.speaker == ConversationSpeaker.user,
      ),
      isTrue,
    );
  });

  test('manual response playback also pauses and resumes recognition',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService()..hold();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(recognition: recognition);
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
    expect(controller.recognitionSuppressed, isTrue);
    expect(recognition.cancelCount, 1);
    recognition.result('そうですね', true, 0.9);
    expect(controller.cueRevision, 0);

    speechService.finish();
    await playback;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    expect(controller.recognitionSuppressed, isFalse);
    expect(recognition.startCount, 2);
  });

  test('Auto Speak off never invokes TTS and still resumes listening',
      () async {
    final recognition = FakeConversationRecognitionService();
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(recognition: recognition);
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
    expect(controller.phase, ConversationAssistPhase.waitingForSpeech);
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
    final speechService = ControlledSpeechService();
    final speech = SpeechController(speechService);
    addTearDown(speech.dispose);
    final controller = ConversationAssistController(recognition: recognition);
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
    await Future<void>.delayed(const Duration(milliseconds: 320));
    expect(speechService.spoken, <String>['지금은 없어요.']);
    expect(speechService.languages, <String>[SpeechController.koreanLocale]);
    expect(recognition.startCount, 2);
  });

  test('recognition language changes apply to the next persistent session',
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
  bool errorClientOnStop = false;
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
  Future<void> start({required ConversationInputLanguage language}) async {
    started = true;
    startCount++;
    languages.add(language);
  }

  void result(String text, bool finalResult, double confidence) {
    callbacks!.onResult(text, finalResult, confidence);
  }

  void status(String status) => callbacks!.onStatus(status);

  void error(String message, {required bool permanent}) =>
      callbacks!.onError(message, permanent: permanent);

  @override
  Future<void> stop() async {
    started = false;
    stopCount++;
    if (errorClientOnStop) {
      callbacks!.onError('error_client', permanent: true);
    }
  }

  @override
  Future<void> cancel() async {
    started = false;
    cancelCount++;
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
  Completer<void>? _gate;

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
  }) async {
    spoken.add(text);
    languages.add(languageCode);
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
