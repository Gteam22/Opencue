import 'dart:async';

import 'package:flutter/foundation.dart';

import '../enums/enums.dart';
import '../models/opener_line.dart';
import '../speech/speech_controller.dart';
import '../speech/tts_text_sanitizer.dart';
import 'conversation_models.dart';
import 'conversation_recognition_service.dart';
import 'conversation_response_engine.dart';
import 'language_detector.dart';
import 'semantic_intent_classifier.dart';
import 'transcript_normalizer.dart';
import 'voice_activity_tracker.dart';

enum ConversationAssistPhase {
  idle,
  initializing,
  waitingForSpeech,
  hearingSpeech,
  understanding,
  speaking,
  suggestions,
  noSpeech,
  unavailable,
  permissionDenied,
  error,
}

class ConversationAssistController extends ChangeNotifier {
  ConversationAssistController({
    required ConversationRecognitionService recognition,
    this.responseEngine = const ConversationResponseEngine(),
    this.semanticClassifier =
        const NullConversationSemanticIntentClassifier(),
    this.normalizer = const TranscriptNormalizer(),
    this.languageDetector = const ConversationLanguageDetector(),
    VoiceActivityTracker? voiceActivity,
  })  : _recognition = recognition,
        voiceActivity = voiceActivity ?? VoiceActivityTracker();

  final ConversationRecognitionService _recognition;
  final ConversationSuggestionProvider responseEngine;
  final ConversationSemanticIntentClassifier semanticClassifier;
  final TranscriptNormalizer normalizer;
  final ConversationLanguageDetector languageDetector;
  final VoiceActivityTracker voiceActivity;

  ConversationAssistPhase _phase = ConversationAssistPhase.idle;
  String _transcript = '';
  String? _errorMessage;
  double _confidence = 0;
  double _soundLevel = 0;
  ConversationSuggestionResult? _result;
  ConversationInputLanguage inputLanguage =
      ConversationInputLanguage.automatic;
  ConversationPreferences preferences = const ConversationPreferences();
  List<OpenerLine> _library = const <OpenerLine>[];
  final List<ConversationTurn> _history = <ConversationTurn>[];
  final List<String> _recentLineIds = <String>[];
  final List<ConversationSuggestionFeedback> _feedback =
      <ConversationSuggestionFeedback>[];
  final Map<String, SuggestionFeedbackKind> _latestFeedback =
      <String, SuggestionFeedbackKind>{};
  Timer? _vadTimer;
  Timer? _restartTimer;
  bool _initialized = false;
  bool _finalizing = false;
  bool _listenModeActive = false;
  bool _recognizerActive = false;
  bool _deliberateRecognizerStop = false;
  bool _suppressRecognition = false;
  double? _sourceConfidence;
  bool _closed = false;
  ConversationPipelineDiagnostics? _diagnostics;
  String? _lastFinalizedNormalized;
  DateTime? _lastFinalizedAt;
  String? _activeCueTranscript;
  String? _activeIntentId;
  final Set<String> _shownResponseIds = <String>{};
  ConversationSuggestionResult? _pendingVariantResult;
  int? _pendingVariantTurnId;
  int _cueRevision = 0;
  int _turnSequence = 0;
  int _activeTurnId = 0;
  SpeechController? _speechController;
  String? _observedSpeakingLineId;
  bool _autoSpeak = false;
  LanguageMode _outputLanguageMode = LanguageMode.bilingual;
  double _speechRate = 0.5;
  bool _japaneseTtsEnabled = true;
  bool _koreanTtsEnabled = true;
  int _consecutiveClientErrors = 0;

  static const Duration duplicateSuppressionWindow = Duration(seconds: 2);
  static const double semanticFallbackThreshold = 0.62;

  ConversationAssistPhase get phase => _phase;
  String get transcript => _transcript;
  String? get errorMessage => _errorMessage;
  double get confidence => _confidence;
  double get soundLevel => _soundLevel;
  ConversationSuggestionResult? get result => _result;
  List<ConversationTurn> get history => List.unmodifiable(_history);
  List<ConversationSuggestionFeedback> get feedback =>
      List.unmodifiable(_feedback);
  ConversationPipelineDiagnostics? get diagnostics => _diagnostics;
  int get cueRevision => _cueRevision;
  String? get activeIntentId => _activeIntentId;
  Set<String> get shownResponseIds => Set.unmodifiable(_shownResponseIds);
  bool get isListening => _listenModeActive;
  bool get listenModeActive => _listenModeActive;
  bool get recognitionSuppressed => _suppressRecognition;
  bool get autoSpeak => _autoSpeak;
  int get activeTurnId => _activeTurnId;

  Future<void> prepare() async {
    if (_initialized) return;
    _setPhase(ConversationAssistPhase.initializing);
    try {
      _initialized = await _recognition.initialize(
        ConversationRecognitionCallbacks(
          onResult: _onRecognitionResult,
          onSoundLevel: _onSoundLevel,
          onStatus: _onStatus,
          onError: _onRecognitionError,
        ),
      );
      _setPhase(_initialized
          ? ConversationAssistPhase.idle
          : ConversationAssistPhase.unavailable);
    } on Object catch (error) {
      _errorMessage = '$error';
      _setPhase(ConversationAssistPhase.unavailable);
    }
  }

  Future<void> start({
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
    SpeechController? speechController,
    bool autoSpeak = false,
    LanguageMode outputLanguageMode = LanguageMode.bilingual,
    double speechRate = 0.5,
    bool japaneseTtsEnabled = true,
    bool koreanTtsEnabled = true,
  }) async {
    if (!_initialized) await prepare();
    if (!_initialized) return;
    _library = library;
    this.preferences = preferences;
    configureAudio(
      speechController: speechController,
      autoSpeak: autoSpeak,
      outputLanguageMode: outputLanguageMode,
      speechRate: speechRate,
      japaneseTtsEnabled: japaneseTtsEnabled,
      koreanTtsEnabled: koreanTtsEnabled,
    );
    _transcript = '';
    _confidence = 0;
    _errorMessage = null;
    _finalizing = false;
    _consecutiveClientErrors = 0;
    _listenModeActive = true;
    _startVadTimer();
    await _startRecognitionCycle();
  }

  /// Turns persistent Listen Mode off. A transcript already in progress is
  /// finalized once; otherwise the recognizer is simply released.
  Future<void> stop() async {
    if (!_listenModeActive) return;
    _listenModeActive = false;
    _vadTimer?.cancel();
    _restartTimer?.cancel();
    final pending = _transcript.trim();
    _deliberateRecognizerStop = true;
    _recognizerActive = false;
    try {
      await _recognition.stop();
    } finally {
      _deliberateRecognizerStop = false;
    }
    if (_speechController?.speakingLineId != null) {
      await _speechController!.stop();
    }
    _suppressRecognition = false;
    if (pending.isNotEmpty && !_finalizing) {
      await onUtteranceFinalized(
        pending,
        library: _library,
        preferences: preferences,
        source: FinalizedUtteranceSource.speech,
        transcriptionConfidence: _confidence,
      );
    }
    _setPhase(_result == null
        ? ConversationAssistPhase.idle
        : ConversationAssistPhase.suggestions);
  }

  Future<void> cancel() async {
    _listenModeActive = false;
    _vadTimer?.cancel();
    _restartTimer?.cancel();
    _activeTurnId = ++_turnSequence;
    _deliberateRecognizerStop = true;
    _recognizerActive = false;
    await _recognition.cancel();
    await _speechController?.stop();
    _deliberateRecognizerStop = false;
    _suppressRecognition = false;
    _setPhase(ConversationAssistPhase.idle);
  }

  void configureAudio({
    SpeechController? speechController,
    required bool autoSpeak,
    required LanguageMode outputLanguageMode,
    required double speechRate,
    required bool japaneseTtsEnabled,
    required bool koreanTtsEnabled,
  }) {
    if (!identical(_speechController, speechController)) {
      _speechController?.removeListener(_onSpeechStateChanged);
      _speechController = speechController;
      _speechController?.addListener(_onSpeechStateChanged);
    }
    _autoSpeak = autoSpeak;
    _outputLanguageMode = outputLanguageMode;
    _speechRate = speechRate;
    _japaneseTtsEnabled = japaneseTtsEnabled;
    _koreanTtsEnabled = koreanTtsEnabled;
  }

  void setAutoSpeak(bool value) {
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    notifyListeners();
  }

  /// Runs a confirmed edit through the exact same finalized-turn pipeline.
  /// Persistent listening is briefly paused so recognition cannot race the
  /// manual correction, then resumes automatically.
  Future<bool> submitManualTranscript(
    String text, {
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
  }) async {
    final shouldResume = _listenModeActive;
    if (shouldResume) {
      _deliberateRecognizerStop = true;
      _recognizerActive = false;
      await _recognition.cancel();
      _deliberateRecognizerStop = false;
    }
    final updated = await onUtteranceFinalized(
      text,
      library: library,
      preferences: preferences,
      source: FinalizedUtteranceSource.manual,
    );
    if (shouldResume && _listenModeActive) _scheduleRecognitionRestart();
    return updated;
  }

  void setInputLanguage(ConversationInputLanguage value) {
    inputLanguage = value;
    notifyListeners();
  }

  void setPreferences(ConversationPreferences value) {
    preferences = value;
    notifyListeners();
    _rerankActiveCue(moreGeneration: false);
  }

  /// The single entry point for completed speech and confirmed manual edits.
  /// Partial recognition updates never call this method.
  Future<bool> onUtteranceFinalized(
    String text, {
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
    FinalizedUtteranceSource source = FinalizedUtteranceSource.manual,
    double? transcriptionConfidence,
  }) async {
    final turnId = ++_turnSequence;
    _activeTurnId = turnId;
    _pendingVariantResult = null;
    _pendingVariantTurnId = null;
    final trimmed = text.trim();
    final normalized = normalizer.normalize(trimmed);
    final now = DateTime.now().toUtc();
    _library = library;
    this.preferences = preferences;
    _transcript = trimmed;

    if (trimmed.isEmpty) {
      _diagnostics = ConversationPipelineDiagnostics(
        rawTranscript: text,
        normalizedTranscript: normalized,
        finalized: true,
        intentId: 'no_action',
        confidence: 0,
        matcher: ConversationMatcherKind.none,
        responsesFound: 0,
        responsesDisplayed: _result?.suggestions.length ?? 0,
        action: CueUpdateAction.preservedEmpty,
        source: source,
        createdAt: now,
      );
      _setPhase(_result == null
          ? ConversationAssistPhase.noSpeech
          : ConversationAssistPhase.suggestions);
      return false;
    }

    final lastAt = _lastFinalizedAt;
    final duplicate = normalized == _lastFinalizedNormalized &&
        lastAt != null &&
        now.difference(lastAt) <= duplicateSuppressionWindow;
    if (duplicate) {
      _diagnostics = ConversationPipelineDiagnostics(
        rawTranscript: trimmed,
        normalizedTranscript: normalized,
        finalized: true,
        intentId: _result?.interpretation.primaryIntentId ?? 'unknown',
        confidence: _result?.interpretation.intentConfidence ?? 0,
        matcher: ConversationMatcherKind.none,
        responsesFound: _result?.candidateCount ?? 0,
        responsesDisplayed: _result?.suggestions.length ?? 0,
        action: CueUpdateAction.preservedDuplicate,
        source: source,
        createdAt: now,
      );
      _setPhase(_result == null
          ? ConversationAssistPhase.idle
          : ConversationAssistPhase.suggestions);
      return false;
    }
    _lastFinalizedNormalized = normalized;
    _lastFinalizedAt = now;

    if (_isNoAction(normalized)) {
      _recordTurn(
        transcript: trimmed,
        language: languageDetector.detect(trimmed),
        intentId: 'no_action',
        confidence: 1,
        createdAt: now,
      );
      _diagnostics = ConversationPipelineDiagnostics(
        rawTranscript: trimmed,
        normalizedTranscript: normalized,
        finalized: true,
        intentId: 'no_action',
        confidence: 1,
        matcher: ConversationMatcherKind.local,
        responsesFound: 0,
        responsesDisplayed: _result?.suggestions.length ?? 0,
        action: CueUpdateAction.preservedIrrelevant,
        source: source,
        createdAt: now,
      );
      _setPhase(_result == null
          ? ConversationAssistPhase.idle
          : ConversationAssistPhase.suggestions);
      return false;
    }

    _setPhase(ConversationAssistPhase.understanding);
    final withRecent = preferences.copyWith(
      recentLineIds: _recentLineIds.toSet(),
    );
    var nextResult = responseEngine.suggest(
      transcript: trimmed,
      library: library,
      preferences: withRecent,
      history: _history,
      transcriptionConfidence: transcriptionConfidence,
    );

    var matcher = nextResult.interpretation.primaryIntent == null
        ? ConversationMatcherKind.none
        : ConversationMatcherKind.local;
    var relevant = _isRelevant(nextResult);
    if (!relevant && _looksLikeContextualFollowUp(normalized)) {
      final prior = _mostRecentIncomingIntent();
      if (prior != null) {
        final contextualResult = responseEngine.suggest(
          transcript: trimmed,
          library: library,
          preferences: withRecent,
          history: _history,
          transcriptionConfidence: transcriptionConfidence,
          semanticIntentId: prior.$1,
          semanticConfidence: prior.$2,
        );
        if (_isRelevant(contextualResult)) {
          nextResult = contextualResult;
          relevant = true;
          matcher = ConversationMatcherKind.contextual;
        }
      }
    }
    if (!relevant) {
      SemanticIntentClassification? semantic;
      try {
        semantic = await semanticClassifier.classify(
          transcript: trimmed,
          recentTurns: List<ConversationTurn>.unmodifiable(_history),
        );
      } on Object catch (error) {
        _errorMessage = 'Semantic classifier: $error';
      }
      if (!_isCurrentTurn(turnId)) return false;
      if (semantic != null &&
          semantic.confidence >= semanticFallbackThreshold) {
        final semanticResult = responseEngine.suggest(
          transcript: trimmed,
          library: library,
          preferences: withRecent,
          history: _history,
          transcriptionConfidence: transcriptionConfidence,
          semanticIntentId: semantic.intentId,
          semanticConfidence: semantic.confidence,
        );
        if (_isRelevant(semanticResult)) {
          nextResult = semanticResult;
          relevant = true;
          matcher = ConversationMatcherKind.semantic;
        }
      }
    }
    if (!_isCurrentTurn(turnId)) return false;

    final intentId = relevant
        ? nextResult.interpretation.primaryIntentId!
        : 'unknown';
    _recordTurn(
      transcript: trimmed,
      language: nextResult.interpretation.language,
      intentId: relevant ? intentId : null,
      topics: <String>{
        ...nextResult.interpretation.topics.map((topic) => topic.name),
        if (relevant) intentId,
      },
      confidence: nextResult.interpretation.intentConfidence,
      createdAt: now,
    );
    if (relevant) {
      final stageVariants = source == FinalizedUtteranceSource.speech &&
          _listenModeActive &&
          nextResult.suggestions.length > 1;
      final displayedResult = stageVariants
          ? nextResult.copyWith(
              suggestions: <ConversationSuggestion>[
                nextResult.suggestions.first,
              ],
            )
          : nextResult;
      _result = displayedResult;
      if (stageVariants) {
        _pendingVariantResult = nextResult;
        _pendingVariantTurnId = turnId;
      }
      _activeCueTranscript = trimmed;
      _activeIntentId = intentId;
      _sourceConfidence = transcriptionConfidence;
      _shownResponseIds
        ..clear()
        ..addAll(displayedResult.suggestions.map((item) => item.line.id));
      _cueRevision++;
      final ids = displayedResult.suggestions.map((item) => item.line.id);
      _remember(ids);
      for (final id in ids) {
        _recordFeedback(id, SuggestionFeedbackKind.shown);
      }
    }

    _diagnostics = ConversationPipelineDiagnostics(
      rawTranscript: trimmed,
      normalizedTranscript: normalized,
      finalized: true,
      intentId: intentId,
      confidence: nextResult.interpretation.intentConfidence,
      matcher: relevant ? matcher : ConversationMatcherKind.none,
      responsesFound: relevant ? nextResult.candidateCount : 0,
      responsesDisplayed: _result?.suggestions.length ?? 0,
      action: relevant
          ? CueUpdateAction.updated
          : CueUpdateAction.preservedIrrelevant,
      source: source,
      createdAt: now,
      matcherReasons: nextResult.interpretation.primaryIntent?.reasons ??
          const <String>[],
      responseHints: nextResult
              .interpretation.primaryIntent?.definition.responseHints ??
          const <String>[],
      topResponseScores: <String, double>{
        for (final suggestion in nextResult.suggestions)
          suggestion.line.id: suggestion.score,
      },
      reelSlotLineIds: _slotLineIds(nextResult),
      excludedAlreadyShown: nextResult.excludedAlreadyShown,
      moreGeneration: nextResult.moreGeneration,
      displayTexts: _displayTexts(nextResult),
      ttsTexts: _ttsTexts(nextResult),
    );
    _setPhase(_result == null
        ? ConversationAssistPhase.idle
        : ConversationAssistPhase.suggestions);
    return relevant;
  }

  void more() {
    _rerankActiveCue(moreGeneration: true);
  }

  void _rerankActiveCue({required bool moreGeneration}) {
    final active = _activeCueTranscript;
    final activeIntent = _activeIntentId;
    if (active == null ||
        active.isEmpty ||
        activeIntent == null ||
        _library.isEmpty) {
      return;
    }
    final next = responseEngine.suggest(
      transcript: active,
      library: _library,
      preferences: preferences.copyWith(
        recentLineIds: _recentLineIds.toSet(),
      ),
      history: _history,
      transcriptionConfidence: _sourceConfidence,
      lockedIntentId: activeIntent,
      excludedLineIds: _shownResponseIds,
      moreGeneration: moreGeneration,
      activeInterpretation: _result?.interpretation,
    );
    if (!_isRelevant(next) ||
        next.interpretation.primaryIntentId != activeIntent) {
      return;
    }
    _result = next;
    _cueRevision++;
    final ids = next.suggestions.map((item) => item.line.id);
    _shownResponseIds.addAll(ids);
    _remember(ids);
    for (final id in ids) {
      _recordFeedback(id, SuggestionFeedbackKind.shown);
    }
    _diagnostics = _diagnostics?.copyWith(
      responsesFound: next.candidateCount,
      responsesDisplayed: next.suggestions.length,
      topResponseScores: <String, double>{
        for (final suggestion in next.suggestions)
          suggestion.line.id: suggestion.score,
      },
      reelSlotLineIds: _slotLineIds(next),
      excludedAlreadyShown: next.excludedAlreadyShown,
      moreGeneration: moreGeneration,
      displayTexts: _displayTexts(next),
      ttsTexts: _ttsTexts(next),
    );
    if (_listenModeActive) {
      _setPhase(_suppressRecognition
          ? ConversationAssistPhase.speaking
          : (voiceActivity.heardSpeech
              ? ConversationAssistPhase.hearingSpeech
              : ConversationAssistPhase.waitingForSpeech));
    } else {
      _setPhase(ConversationAssistPhase.suggestions);
    }
  }

  Map<String, String> _slotLineIds(ConversationSuggestionResult result) =>
      <String, String>{
        for (final suggestion in result.suggestions)
          (suggestion.slot?.name ?? 'fallback'): suggestion.line.id,
      };

  Map<String, String> _displayTexts(ConversationSuggestionResult result) =>
      <String, String>{
        for (final suggestion in result.suggestions)
          suggestion.line.id: suggestion.line.japaneseText,
      };

  Map<String, String> _ttsTexts(ConversationSuggestionResult result) =>
      <String, String>{
        for (final suggestion in result.suggestions)
          suggestion.line.id: const TtsTextSanitizer()
              .sanitize(suggestion.line.japaneseText),
      };

  bool _isRelevant(ConversationSuggestionResult candidate) {
    final intent = candidate.interpretation.primaryIntent;
    return intent != null &&
        intent.confidence >= intent.definition.confidenceThreshold &&
        !candidate.lowRecognitionConfidence &&
        candidate.suggestions.isNotEmpty;
  }

  bool _isNoAction(String normalized) => const <String>{
        'ありがとう',
        'ありがとうございます',
        'すみません',
        'ごめん',
        'うん',
        'はい',
        'そうですね',
        'そうだね',
        'thankyou',
        'thanks',
        'yes',
        'yeah',
        '네',
        '응',
        '감사합니다',
      }.contains(normalized);

  void _recordTurn({
    required String transcript,
    required DetectedLanguage language,
    required String? intentId,
    required double confidence,
    required DateTime createdAt,
    ConversationSpeaker speaker = ConversationSpeaker.other,
    Set<String> topics = const <String>{},
  }) {
    _history.insert(
      0,
      ConversationTurn(
        id: 'turn-${createdAt.microsecondsSinceEpoch}-${_history.length}',
        transcript: transcript,
        language: language,
        createdAt: createdAt,
        speaker: speaker,
        detectedIntent: intentId,
        detectedTopics: topics,
        confidence: confidence,
      ),
    );
    if (_history.length > 12) _history.removeRange(12, _history.length);
  }

  SuggestionFeedbackKind? feedbackFor(String lineId) =>
      _latestFeedback[lineId];

  void acceptSuggestion(String lineId) {
    if (_latestFeedback[lineId] == SuggestionFeedbackKind.accepted) return;
    _recordFeedback(lineId, SuggestionFeedbackKind.accepted);
    _recordSpokenOrSelectedResponse(lineId);
    notifyListeners();
  }

  void dismissSuggestion(String lineId) {
    if (_latestFeedback[lineId] == SuggestionFeedbackKind.dismissed) return;
    _recordFeedback(lineId, SuggestionFeedbackKind.dismissed);
    notifyListeners();
  }

  void _recordFeedback(String lineId, SuggestionFeedbackKind kind) {
    _feedback.add(ConversationSuggestionFeedback(
      transcript: _activeCueTranscript ?? _transcript,
      intentId: _result?.interpretation.primaryIntentId,
      lineId: lineId,
      kind: kind,
      createdAt: DateTime.now().toUtc(),
    ));
    if (kind != SuggestionFeedbackKind.shown) {
      _latestFeedback[lineId] = kind;
    }
    while (_feedback.length > 60) _feedback.removeAt(0);
  }

  bool _isCurrentTurn(int turnId) =>
      !_closed && turnId == _activeTurnId;

  (String, double)? _mostRecentIncomingIntent() {
    for (final turn in _history) {
      if (turn.speaker != ConversationSpeaker.other ||
          turn.detectedIntent == null ||
          turn.detectedIntent == 'no_action') {
        continue;
      }
      final confidence = ((turn.confidence ?? 0.75) * 0.92)
          .clamp(0.68, 0.92)
          .toDouble();
      return (turn.detectedIntent!, confidence);
    }
    return null;
  }

  bool _looksLikeContextualFollowUp(String normalized) {
    if (normalized.runes.length > 26) return false;
    return const <String>[
      '何年',
      'どのくらい',
      'どれくらい',
      'それで',
      'じゃあ',
      '本当',
      '具体的には',
      '왜',
      '얼마나',
      '몇년',
      '그래서',
      '그럼',
      '정말',
      'howlong',
      'howmany',
      'why',
      'really',
      'andyou',
      'whataboutyou',
    ].any(normalized.contains);
  }

  void _recordSpokenOrSelectedResponse(
    String lineId, {
    String? languageCode,
  }) {
    OpenerLine? line;
    for (final suggestion in _result?.suggestions ??
        const <ConversationSuggestion>[]) {
      if (suggestion.line.id == lineId) {
        line = suggestion.line;
        break;
      }
    }
    if (line == null) {
      for (final candidate in _library) {
        if (candidate.id == lineId) {
          line = candidate;
          break;
        }
      }
    }
    if (line == null) return;
    final korean = line.koreanText;
    final useKorean = languageCode == SpeechController.koreanLocale ||
        (languageCode == null &&
            _outputLanguageMode == LanguageMode.korean);
    final transcript = useKorean &&
            korean != null &&
            korean.trim().isNotEmpty
        ? korean
        : line.japaneseText;
    _recordTurn(
      transcript: transcript,
      language: languageDetector.detect(transcript),
      intentId: _activeIntentId,
      topics: line.topics,
      confidence: 1,
      createdAt: DateTime.now().toUtc(),
      speaker: ConversationSpeaker.user,
    );
  }

  void _startVadTimer() {
    _vadTimer?.cancel();
    _vadTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_listenModeActive ||
          !_recognizerActive ||
          _suppressRecognition ||
          _finalizing) {
        return;
      }
      final now = DateTime.now();
      if (voiceActivity.heardSpeech &&
          _phase == ConversationAssistPhase.waitingForSpeech) {
        _setPhase(ConversationAssistPhase.hearingSpeech);
      }
      if (voiceActivity.shouldStop(now)) {
        unawaited(_finalizeTranscript());
      }
    });
  }

  Future<void> _startRecognitionCycle() async {
    if (!_listenModeActive ||
        _closed ||
        _recognizerActive ||
        _finalizing ||
        _suppressRecognition) {
      return;
    }
    if (_speechController?.speakingLineId != null) {
      _suppressRecognition = true;
      _setPhase(ConversationAssistPhase.speaking);
      return;
    }
    voiceActivity.reset();
    _transcript = '';
    _confidence = 0;
    _recognizerActive = true;
    _setPhase(ConversationAssistPhase.waitingForSpeech);
    try {
      await _recognition.start(language: inputLanguage);
    } on Object catch (error) {
      _recognizerActive = false;
      _listenModeActive = false;
      _errorMessage = '$error';
      _setPhase(ConversationAssistPhase.error);
    }
  }

  void _scheduleRecognitionRestart({
    Duration delay = const Duration(milliseconds: 120),
  }) {
    if (!_listenModeActive || _suppressRecognition || _closed) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () {
      unawaited(_startRecognitionCycle());
    });
  }

  Future<void> _finalizeTranscript() async {
    if (_finalizing || !_listenModeActive || _suppressRecognition) return;
    _finalizing = true;
    final finalizedText = _transcript.trim();
    final finalizedConfidence = _confidence;
    _recognizerActive = false;
    _deliberateRecognizerStop = true;
    try {
      await _recognition.stop();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      if (finalizedText.isNotEmpty) {
        final finalizedTurnId = _turnSequence + 1;
        final relevant = await onUtteranceFinalized(
          finalizedText,
          library: _library,
          preferences: preferences,
          source: FinalizedUtteranceSource.speech,
          transcriptionConfidence: finalizedConfidence,
        );
        if (!_isCurrentTurn(finalizedTurnId)) return;
        if (relevant &&
            _autoSpeak &&
            _listenModeActive &&
            _isCurrentTurn(finalizedTurnId)) {
          final speaking = _speakPrimarySuggestion(finalizedTurnId);
          await Future<void>.delayed(Duration.zero);
          _publishPendingVariants(finalizedTurnId);
          await speaking;
        } else {
          await Future<void>.delayed(Duration.zero);
          _publishPendingVariants(finalizedTurnId);
        }
      }
    } on Object catch (error) {
      _errorMessage = '$error';
      if (_listenModeActive) _setPhase(ConversationAssistPhase.error);
    } finally {
      _deliberateRecognizerStop = false;
      _finalizing = false;
      if (_listenModeActive && !_suppressRecognition) {
        _scheduleRecognitionRestart();
      }
    }
  }

  void _onRecognitionResult(String text, bool isFinal, double confidence) {
    if (!_listenModeActive ||
        !_recognizerActive ||
        _suppressRecognition ||
        _deliberateRecognizerStop) {
      return;
    }
    if (text.trim().isNotEmpty) _transcript = text.trim();
    if (text.trim().isNotEmpty) _consecutiveClientErrors = 0;
    _confidence = confidence;
    if (_transcript.isNotEmpty &&
        _phase == ConversationAssistPhase.waitingForSpeech) {
      _setPhase(ConversationAssistPhase.hearingSpeech);
    } else {
      notifyListeners();
    }
    if (isFinal && isListening) unawaited(_finalizeTranscript());
  }

  void _onSoundLevel(double level) {
    if (!_listenModeActive || !_recognizerActive || _suppressRecognition) {
      return;
    }
    _soundLevel = level;
    voiceActivity.addLevel(level, DateTime.now());
    if (voiceActivity.heardSpeech &&
        _phase == ConversationAssistPhase.waitingForSpeech) {
      _setPhase(ConversationAssistPhase.hearingSpeech);
      return;
    }
    notifyListeners();
  }

  void _onStatus(String status) {
    if (_deliberateRecognizerStop || _suppressRecognition) return;
    if ((status == 'done' || status == 'notListening') &&
        _listenModeActive) {
      _recognizerActive = false;
      if (_transcript.trim().isNotEmpty || voiceActivity.heardSpeech) {
        _recognizerActive = true;
        unawaited(_finalizeTranscript());
      } else {
        _scheduleRecognitionRestart();
      }
    }
  }

  void _onRecognitionError(String message, {required bool permanent}) {
    final normalized = message.toLowerCase();
    // Android may emit ERROR_CLIENT as the recognizer acknowledges our own
    // stop/cancel request. That is lifecycle noise, not a failed user turn.
    if (_deliberateRecognizerStop || _suppressRecognition) return;
    if (normalized.contains('error_client') && _listenModeActive) {
      _recognizerActive = false;
      _consecutiveClientErrors++;
      if (_consecutiveClientErrors <= 2) {
        _errorMessage = null;
        _setPhase(ConversationAssistPhase.waitingForSpeech);
        _scheduleRecognitionRestart(
          delay: const Duration(milliseconds: 400),
        );
        return;
      }
    }
    _errorMessage = message;
    if (normalized.contains('no_match') ||
        normalized.contains('speech_timeout')) {
      _recognizerActive = false;
      if (_listenModeActive) _scheduleRecognitionRestart();
      return;
    }
    final permission = normalized.contains('permission') ||
        normalized.contains('notallowed');
    if (!permanent && !permission && _listenModeActive) {
      _recognizerActive = false;
      _scheduleRecognitionRestart();
      return;
    }
    _listenModeActive = false;
    _recognizerActive = false;
    _vadTimer?.cancel();
    _setPhase(permission
        ? ConversationAssistPhase.permissionDenied
        : ConversationAssistPhase.error);
  }

  Future<void> _speakPrimarySuggestion(int turnId) async {
    final speech = _speechController;
    final suggestions = _result?.suggestions;
    if (speech == null ||
        !speech.isSupported ||
        suggestions == null ||
        suggestions.isEmpty ||
        !_isCurrentTurn(turnId)) {
      return;
    }
    final line = suggestions.first.line;
    _suppressRecognition = true;
    _recognizerActive = false;
    _setPhase(ConversationAssistPhase.speaking);
    try {
      await _recognition.cancel();
      if (_outputLanguageMode == LanguageMode.korean) {
        if (_koreanTtsEnabled &&
            line.ttsKorean &&
            line.koreanText?.trim().isNotEmpty == true &&
            await speech.ensureKoreanChecked()) {
          await speech.toggleKorean(
            lineId: line.id,
            koreanText: line.koreanText!,
            rate: _speechRate,
          );
        }
      } else if (_japaneseTtsEnabled &&
          line.ttsJapanese &&
          await speech.ensureJapaneseChecked()) {
        await speech.toggleJapanese(
          lineId: line.id,
          japaneseText: line.japaneseText,
          rate: _speechRate,
        );
      }
    } finally {
      _suppressRecognition = false;
      voiceActivity.reset();
    }
  }

  void _publishPendingVariants(int turnId) {
    final full = _pendingVariantResult;
    if (full == null ||
        _pendingVariantTurnId != turnId ||
        !_isCurrentTurn(turnId)) {
      return;
    }
    final previousIds = _result?.suggestions
            .map((item) => item.line.id)
            .toSet() ??
        const <String>{};
    _pendingVariantResult = null;
    _pendingVariantTurnId = null;
    _result = full;
    final newlyVisible = full.suggestions
        .map((item) => item.line.id)
        .where((id) => !previousIds.contains(id));
    _shownResponseIds.addAll(newlyVisible);
    _remember(newlyVisible);
    for (final id in newlyVisible) {
      _recordFeedback(id, SuggestionFeedbackKind.shown);
    }
    _diagnostics = _diagnostics?.copyWith(
      responsesDisplayed: full.suggestions.length,
      displayTexts: _displayTexts(full),
      ttsTexts: _ttsTexts(full),
      reelSlotLineIds: _slotLineIds(full),
    );
    notifyListeners();
  }

  void _onSpeechStateChanged() {
    final lineId = _speechController?.speakingLineId;
    if (lineId != null) {
      if (_observedSpeakingLineId != lineId) {
        _observedSpeakingLineId = lineId;
        _recordSpokenOrSelectedResponse(
          lineId,
          languageCode: _speechController?.speakingLanguageCode,
        );
      }
      if (_listenModeActive) {
        _setPhase(ConversationAssistPhase.speaking);
        if (!_suppressRecognition) {
          _suppressRecognition = true;
          unawaited(_pauseRecognitionForSpeech());
        }
      }
      return;
    }
    if (_observedSpeakingLineId != null) {
      _observedSpeakingLineId = null;
      if (_listenModeActive && _suppressRecognition && !_finalizing) {
        _suppressRecognition = false;
        voiceActivity.reset();
        _scheduleRecognitionRestart();
      }
    }
  }

  Future<void> _pauseRecognitionForSpeech() async {
    _deliberateRecognizerStop = true;
    _recognizerActive = false;
    try {
      await _recognition.cancel();
    } finally {
      _deliberateRecognizerStop = false;
    }
  }

  void _remember(Iterable<String> ids) {
    for (final id in ids) {
      _recentLineIds.remove(id);
      _recentLineIds.add(id);
    }
    while (_recentLineIds.length > 15) _recentLineIds.removeAt(0);
  }

  void _setPhase(ConversationAssistPhase value) {
    _phase = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _vadTimer?.cancel();
    _restartTimer?.cancel();
    _speechController?.removeListener(_onSpeechStateChanged);
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _vadTimer?.cancel();
    _restartTimer?.cancel();
    _speechController?.removeListener(_onSpeechStateChanged);
    await _recognition.dispose();
  }
}
