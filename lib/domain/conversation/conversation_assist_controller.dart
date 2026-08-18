import 'dart:async';

import 'package:flutter/foundation.dart';

import '../enums/enums.dart';
import '../models/opener_line.dart';
import '../speech/speech_controller.dart';
import '../speech/tts_text_sanitizer.dart';
import 'conversation_models.dart';
import 'conversation_recognition_service.dart';
import 'conversation_response_engine.dart';
import 'conversation_speech_log.dart';
import 'language_detector.dart';
import 'semantic_intent_classifier.dart';
import 'transcript_normalizer.dart';

enum ConversationAssistPhase {
  idle,
  initializing,
  starting,
  waitingForSpeech,
  hearingSpeech,
  understanding,
  speaking,
  stopping,
  suggestions,
  noSpeech,
  unavailable,
  permissionDenied,
  error,
}

/// The microphone/TTS ownership state. There is deliberately no continuous
/// listening state: one tap creates one LISTENING session and every terminal
/// path returns to IDLE.
enum ConversationSpeechState {
  idle,
  starting,
  readyForSpeech,
  speechDetected,
  processing,
  stopping,
  ttsPlaying,
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
    this.logger = const ConversationSpeechLogger(),
    this.startupWatchdogDuration = const Duration(seconds: 8),
  }) : _recognition = recognition;

  final ConversationRecognitionService _recognition;
  final ConversationSuggestionProvider responseEngine;
  final ConversationSemanticIntentClassifier semanticClassifier;
  final TranscriptNormalizer normalizer;
  final ConversationLanguageDetector languageDetector;
  final ConversationSpeechLogger logger;
  final Duration startupWatchdogDuration;

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
  bool _initialized = false;
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
  ConversationSpeechState _speechState = ConversationSpeechState.idle;
  int _sessionSequence = 0;
  int? _activeSessionId;
  Timer? _startupWatchdog;
  Future<void>? _recognitionCleanup;
  String? _recognitionLocale;
  String? _recognitionStrategy;
  String _nativeRecognitionStatus = 'IDLE';

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
  bool get isListening => switch (_speechState) {
        ConversationSpeechState.starting ||
        ConversationSpeechState.readyForSpeech ||
        ConversationSpeechState.speechDetected => true,
        _ => false,
      };
  bool get listenModeActive => switch (_speechState) {
        ConversationSpeechState.idle || ConversationSpeechState.error => false,
        _ => true,
      };
  bool get recognitionSuppressed => _suppressRecognition;
  bool get autoSpeak => _autoSpeak;
  int get activeTurnId => _activeTurnId;
  int? get activeRecognitionSessionId => _activeSessionId;
  ConversationSpeechState get speechState => _speechState;
  String? get recognitionLocale => _recognitionLocale;
  String? get recognitionStrategy => _recognitionStrategy;
  String get nativeRecognitionStatus => _nativeRecognitionStatus;

  Future<void> prepare() async {
    if (_initialized) return;
    _setPhase(ConversationAssistPhase.initializing);
    logger.event(sessionId: 0, state: 'INITIALIZING', event: 'prepare');
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
    final pendingCleanup = _recognitionCleanup;
    if (pendingCleanup != null) await pendingCleanup;
    if (_closed) return;
    if (_speechState != ConversationSpeechState.idle ||
        _activeSessionId != null) {
      logger.event(
        sessionId: _activeSessionId ?? 0,
        state: _speechState.name.toUpperCase(),
        event: 'tap_ignored_not_idle',
      );
      return;
    }
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
    if (_speechController?.speakingLineId != null) {
      logger.event(
        sessionId: 0,
        state: 'IDLE',
        event: 'tap_ignored_tts_active',
      );
      return;
    }
    _transcript = '';
    _confidence = 0;
    _errorMessage = null;
    final sessionId = ++_sessionSequence;
    _activeSessionId = sessionId;
    _recognitionLocale = null;
    _recognitionStrategy = null;
    _nativeRecognitionStatus = 'START_REQUESTED';
    final effectiveLanguage = _effectiveInputLanguage(outputLanguageMode);
    logger.event(
      sessionId: sessionId,
      state: 'IDLE',
      event: 'user_pressed_listen',
      details: <String, Object?>{
        'selectedInput': inputLanguage.name,
        'outputLanguageMode': outputLanguageMode.name,
        'effectiveRecognitionMode': effectiveLanguage.name,
      },
    );
    _setSpeechState(
      ConversationSpeechState.starting,
      sessionId,
      'start_requested',
    );
    _setPhase(ConversationAssistPhase.starting);
    _armStartupWatchdog(sessionId);
    try {
      final info = await _recognition.start(
        sessionId: sessionId,
        language: effectiveLanguage,
      );
      if (_activeSessionId != sessionId) return;
      _recognitionLocale = info.localeId;
      _recognitionStrategy = info.strategy;
      logger.event(
        sessionId: sessionId,
        state: _speechState.name.toUpperCase(),
        event: 'recognition_configuration_applied',
        details: <String, Object?>{
          'recognitionLanguage': info.localeId,
          'strategy': info.strategy,
          'languageDetectionSupported':
              info.nativeLanguageDetectionSupported,
          'languageSwitchingSupported':
              info.nativeLanguageSwitchingSupported,
        },
      );
      notifyListeners();
    } on Object catch (error) {
      if (_activeSessionId != sessionId) return;
      _activeSessionId = null;
      _errorMessage = '$error';
      _recoverFromRecognitionError(
        sessionId,
        event: 'start_failed',
        phase: ConversationAssistPhase.error,
      );
    }
  }

  ConversationInputLanguage _effectiveInputLanguage(LanguageMode outputMode) {
    if (inputLanguage != ConversationInputLanguage.automatic) {
      return inputLanguage;
    }
    return switch (outputMode) {
      LanguageMode.japanese => ConversationInputLanguage.japanese,
      LanguageMode.korean => ConversationInputLanguage.korean,
      LanguageMode.both => ConversationInputLanguage.both,
      LanguageMode.english || LanguageMode.bilingual =>
        ConversationInputLanguage.automatic,
    };
  }

  /// Immediately invalidates and cancels the current manual Listen session.
  Future<void> stop() async {
    final sessionId = _activeSessionId;
    if (!listenModeActive && sessionId == null) return;
    final wasTtsPlaying =
        _speechState == ConversationSpeechState.ttsPlaying;
    logger.event(
      sessionId: sessionId ?? 0,
      state: _speechState.name.toUpperCase(),
      event: 'stop_button_pressed',
    );
    _startupWatchdog?.cancel();
    _activeSessionId = null;
    _activeTurnId = ++_turnSequence;
    _nativeRecognitionStatus = 'CANCELLED_BY_USER';
    _setSpeechState(
      ConversationSpeechState.stopping,
      sessionId ?? 0,
      'session_invalidated',
    );
    _setPhase(ConversationAssistPhase.stopping);
    final cleanup = _cancelStoppedSession(
      sessionId,
      stopTts: wasTtsPlaying,
    );
    _recognitionCleanup = cleanup;
    _suppressRecognition = false;
    _setSpeechState(
      ConversationSpeechState.idle,
      sessionId ?? 0,
      'stop_returned_to_idle',
    );
    _setPhase(ConversationAssistPhase.idle);
    try {
      await cleanup;
    } finally {
      if (identical(_recognitionCleanup, cleanup)) {
        _recognitionCleanup = null;
      }
    }
  }

  Future<void> _cancelStoppedSession(
    int? sessionId, {
    required bool stopTts,
  }) async {
    try {
      if (sessionId != null) {
        logger.event(
          sessionId: sessionId,
          state: 'STOPPING',
          event: 'recognizer_cancel_requested',
        );
        await _recognition.cancel(sessionId: sessionId);
      }
      if (stopTts) await _speechController?.stop();
      logger.event(
        sessionId: sessionId ?? 0,
        state: 'IDLE',
        event: 'stop_cleanup_complete',
      );
    } on Object catch (error) {
      logger.event(
        sessionId: sessionId ?? 0,
        state: 'IDLE',
        event: 'stop_cleanup_error_ignored',
        details: <String, Object?>{'message': error},
      );
    }
  }

  Future<void> cancel() async {
    final sessionId = _activeSessionId;
    _startupWatchdog?.cancel();
    _activeTurnId = ++_turnSequence;
    _activeSessionId = null;
    if (sessionId != null) {
      await _recognition.cancel(sessionId: sessionId);
    }
    await _speechController?.stop();
    _suppressRecognition = false;
    _setSpeechState(
      ConversationSpeechState.idle,
      sessionId ?? 0,
      'cancel_complete',
    );
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
      _speechController?.setPlaybackGuard(null);
      _speechController = speechController;
      _speechController?.addListener(_onSpeechStateChanged);
      _speechController?.setPlaybackGuard(() => _activeSessionId == null);
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

  /// Runs a confirmed edit through the same finalized-turn pipeline. If a
  /// microphone session is active it is cancelled and is never auto-restarted.
  Future<bool> submitManualTranscript(
    String text, {
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
  }) async {
    final sessionId = _activeSessionId;
    _startupWatchdog?.cancel();
    if (sessionId != null) {
      _activeSessionId = null;
      await _recognition.cancel(sessionId: sessionId);
    }
    _setSpeechState(
      ConversationSpeechState.processing,
      sessionId ?? 0,
      'manual_transcript',
    );
    final updated = await onUtteranceFinalized(
      text,
      library: library,
      preferences: preferences,
      source: FinalizedUtteranceSource.manual,
    );
    _setSpeechState(
      ConversationSpeechState.idle,
      sessionId ?? 0,
      'manual_processing_complete',
    );
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
    _setPhase(switch (_speechState) {
      ConversationSpeechState.starting => ConversationAssistPhase.starting,
      ConversationSpeechState.readyForSpeech =>
        ConversationAssistPhase.waitingForSpeech,
      ConversationSpeechState.speechDetected =>
        ConversationAssistPhase.hearingSpeech,
      ConversationSpeechState.processing =>
        ConversationAssistPhase.understanding,
      ConversationSpeechState.stopping => ConversationAssistPhase.stopping,
      ConversationSpeechState.ttsPlaying => ConversationAssistPhase.speaking,
      ConversationSpeechState.idle || ConversationSpeechState.error =>
        ConversationAssistPhase.suggestions,
    });
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

  Future<void> _completeSpeechSession(int sessionId, String text) async {
    if (_activeSessionId != sessionId || _closed) return;
    _startupWatchdog?.cancel();
    _activeSessionId = null;
    _nativeRecognitionStatus = 'TERMINAL';
    _setSpeechState(
      ConversationSpeechState.processing,
      sessionId,
      'recognition_terminal',
    );
    final finalizedText = text.trim();
    if (finalizedText.isEmpty) {
      _setPhase(_result == null
          ? ConversationAssistPhase.noSpeech
          : ConversationAssistPhase.suggestions);
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'no_speech_complete',
      );
      return;
    }
    final finalizedTurnId = _turnSequence + 1;
    final relevant = await onUtteranceFinalized(
      finalizedText,
      library: _library,
      preferences: preferences,
      source: FinalizedUtteranceSource.speech,
      transcriptionConfidence: _confidence,
    );
    if (!_isCurrentTurn(finalizedTurnId) || _closed) return;
    if (relevant && _autoSpeak) {
      final speaking = _speakPrimarySuggestion(finalizedTurnId, sessionId);
      await Future<void>.delayed(Duration.zero);
      _publishPendingVariants(finalizedTurnId);
      await speaking;
    } else {
      await Future<void>.delayed(Duration.zero);
      _publishPendingVariants(finalizedTurnId);
    }
    if (_speechState != ConversationSpeechState.ttsPlaying) {
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'processing_complete',
      );
      _setPhase(_result == null
          ? ConversationAssistPhase.idle
          : ConversationAssistPhase.suggestions);
    }
  }

  void _onRecognitionResult(
    int sessionId,
    String text,
    bool isFinal,
    double confidence,
  ) {
    if (_activeSessionId != sessionId || _suppressRecognition) return;
    _startupWatchdog?.cancel();
    if (text.trim().isNotEmpty) _transcript = text.trim();
    _confidence = confidence;
    _nativeRecognitionStatus = isFinal ? 'FINAL_RESULT' : 'PARTIAL_RESULT';
    if (_transcript.isNotEmpty && !isFinal) {
      _setSpeechState(
        ConversationSpeechState.speechDetected,
        sessionId,
        'speech_result_detected',
      );
      _setPhase(ConversationAssistPhase.hearingSpeech);
    } else {
      notifyListeners();
    }
    logger.event(
      sessionId: sessionId,
      state: isFinal ? 'PROCESSING' : 'LISTENING',
      event: isFinal ? 'controller_final' : 'controller_partial',
      details: <String, Object?>{'confidence': confidence},
    );
    if (isFinal) {
      // A final transcript is not the native terminal signal. Keep this
      // session token until `done`/`notListening` so the next tap cannot race
      // an Android recognizer that is still releasing its audio resources.
      _setSpeechState(
        ConversationSpeechState.processing,
        sessionId,
        'final_waiting_for_terminal_status',
      );
      _setPhase(ConversationAssistPhase.understanding);
    }
  }

  void _onSoundLevel(int sessionId, double level) {
    if (_activeSessionId != sessionId) return;
    _soundLevel = level;
    if (_speechState == ConversationSpeechState.starting) {
      // speech_to_text exposes Android onRmsChanged as sound-level callbacks.
      // This is the first public event proving that the native recognizer has
      // an active audio listener; its earlier `listening` status is emitted by
      // the plugin before Android creates the recognizer.
      _startupWatchdog?.cancel();
      _nativeRecognitionStatus = 'AUDIO_ACTIVE';
      _setSpeechState(
        ConversationSpeechState.readyForSpeech,
        sessionId,
        'native_audio_callback_ready',
      );
      _setPhase(ConversationAssistPhase.waitingForSpeech);
      return;
    }
    notifyListeners();
  }

  void _onStatus(int sessionId, String status) {
    if (_activeSessionId != sessionId) return;
    logger.event(
      sessionId: sessionId,
      state: _speechState.name.toUpperCase(),
      event: 'controller_status',
      details: <String, Object?>{'value': status},
    );
    _nativeRecognitionStatus = 'PLUGIN_${status.toUpperCase()}';
    if (status == 'listening' &&
        _speechState == ConversationSpeechState.starting) {
      // This plugin status is a start-request acknowledgement, not Android's
      // onReadyForSpeech. Remain STARTING until audio/result callbacks prove
      // the native listener is alive.
      notifyListeners();
      return;
    }
    if (status.startsWith('done') || status == 'notListening') {
      _startupWatchdog?.cancel();
      unawaited(_completeSpeechSession(sessionId, _transcript));
    }
  }

  void _onRecognitionError(
    int sessionId,
    String message, {
    required bool permanent,
    int? platformCode,
  }) {
    if (_activeSessionId != sessionId) return;
    _startupWatchdog?.cancel();
    _activeSessionId = null;
    _nativeRecognitionStatus = 'ERROR';
    final normalized = message.toLowerCase();
    _errorMessage = message;
    final permission = normalized.contains('permission') ||
        normalized.contains('notallowed');
    logger.event(
      sessionId: sessionId,
      state: 'ERROR',
      event: 'controller_error',
      details: <String, Object?>{
        'message': message,
        'platformCode': platformCode,
        'permanent': permanent,
      },
    );
    _recoverFromRecognitionError(
      sessionId,
      event: 'recognition_error_complete',
      phase: permission
          ? ConversationAssistPhase.permissionDenied
          : ConversationAssistPhase.error,
    );
  }

  Future<void> _speakPrimarySuggestion(int turnId, int sessionId) async {
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
    _setSpeechState(
      ConversationSpeechState.ttsPlaying,
      sessionId,
      'tts_start',
    );
    _setPhase(ConversationAssistPhase.speaking);
    try {
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
      if (_isCurrentTurn(turnId)) {
        _setSpeechState(
          ConversationSpeechState.idle,
          sessionId,
          'tts_complete',
        );
        _setPhase(_result == null
            ? ConversationAssistPhase.idle
            : ConversationAssistPhase.suggestions);
      }
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
      final activeRecognition = _activeSessionId;
      if (activeRecognition != null) {
        logger.event(
          sessionId: activeRecognition,
          state: _speechState.name.toUpperCase(),
          event: 'tts_rejected_recognition_active',
        );
        // Recognition owns the audio session until its native terminal event.
        // Stop the newly requested playback; never cancel/stop recognition
        // after TTS has begun.
        unawaited(_speechController?.stop());
        return;
      }
      if (_observedSpeakingLineId != lineId) {
        _observedSpeakingLineId = lineId;
        _recordSpokenOrSelectedResponse(
          lineId,
          languageCode: _speechController?.speakingLanguageCode,
        );
      }
      _setPhase(ConversationAssistPhase.speaking);
      if (!_suppressRecognition) {
        _suppressRecognition = true;
        const sessionId = 0;
        _setSpeechState(
          ConversationSpeechState.ttsPlaying,
          sessionId,
          'manual_tts_start',
        );
      }
      return;
    }
    if (_observedSpeakingLineId != null) {
      _observedSpeakingLineId = null;
      if (_suppressRecognition) {
        _suppressRecognition = false;
        _setSpeechState(
          ConversationSpeechState.idle,
          0,
          'manual_tts_complete',
        );
        _setPhase(_result == null
            ? ConversationAssistPhase.idle
            : ConversationAssistPhase.suggestions);
      }
    }
  }

  void _recoverFromRecognitionError(
    int sessionId, {
    required String event,
    required ConversationAssistPhase phase,
  }) {
    _setSpeechState(ConversationSpeechState.error, sessionId, event);
    _setPhase(phase);
    // ERROR is terminal and immediately usable: keep the diagnostic phase and
    // message visible while returning microphone ownership to IDLE.
    _setSpeechState(
      ConversationSpeechState.idle,
      sessionId,
      'error_recovered_to_idle',
      notify: false,
    );
  }

  void _armStartupWatchdog(int sessionId) {
    _startupWatchdog?.cancel();
    _startupWatchdog = Timer(startupWatchdogDuration, () {
      if (_closed ||
          _activeSessionId != sessionId ||
          _speechState != ConversationSpeechState.starting) {
        return;
      }
      logger.event(
        sessionId: sessionId,
        state: 'STARTING',
        event: 'SPEECH_RECOGNIZER_STALLED',
        details: <String, Object?>{
          'timeoutMs': startupWatchdogDuration.inMilliseconds,
          'nativeStatus': _nativeRecognitionStatus,
        },
      );
      _activeSessionId = null;
      _nativeRecognitionStatus = 'STARTUP_STALLED';
      _errorMessage = 'Speech recognizer did not activate. Please try again.';
      _setSpeechState(
        ConversationSpeechState.error,
        sessionId,
        'startup_watchdog_failed',
      );
      _setPhase(ConversationAssistPhase.error);
      unawaited(_cancelStalledSession(sessionId));
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'startup_watchdog_returned_to_idle',
        notify: false,
      );
    });
  }

  Future<void> _cancelStalledSession(int sessionId) async {
    try {
      await _recognition.cancel(sessionId: sessionId);
    } on Object catch (error) {
      logger.event(
        sessionId: sessionId,
        state: 'IDLE',
        event: 'stalled_cancel_error_ignored',
        details: <String, Object?>{'message': error},
      );
    }
  }

  void _setSpeechState(
    ConversationSpeechState value,
    int sessionId,
    String event, {
    bool notify = true,
  }) {
    _speechState = value;
    logger.event(
      sessionId: sessionId,
      state: value.name.toUpperCase(),
      event: event,
    );
    _logIllegalStateIfNeeded(sessionId);
    if (notify) notifyListeners();
  }

  void _logIllegalStateIfNeeded(int sessionId) {
    final needsSession = _speechState == ConversationSpeechState.starting ||
        _speechState == ConversationSpeechState.readyForSpeech ||
        _speechState == ConversationSpeechState.speechDetected;
    final illegal = (needsSession && _activeSessionId == null) ||
        (_speechState == ConversationSpeechState.idle &&
            _activeSessionId != null);
    if (!illegal) return;
    logger.event(
      sessionId: sessionId,
      state: _speechState.name.toUpperCase(),
      event: 'ILLEGAL_STATE',
      details: <String, Object?>{
        'activeSession': _activeSessionId,
      },
    );
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
    _startupWatchdog?.cancel();
    _speechController?.removeListener(_onSpeechStateChanged);
    _speechController?.setPlaybackGuard(null);
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _startupWatchdog?.cancel();
    _activeSessionId = null;
    _speechController?.removeListener(_onSpeechStateChanged);
    _speechController?.setPlaybackGuard(null);
    final cleanup = _recognitionCleanup;
    if (cleanup != null) await cleanup;
    await _recognition.dispose();
  }
}
