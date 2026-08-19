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
  capturingUtterance,
  finalizing,
  understanding,
  primaryReady,
  speaking,
  resuming,
  stopping,
  suggestions,
  noSpeech,
  unavailable,
  permissionDenied,
  error,
}

/// The exclusive microphone/processing/TTS ownership state.
enum ConversationSpeechState {
  idle,
  starting,
  readyForSpeech,
  speechDetected,
  capturingUtterance,
  finalizing,
  processing,
  primaryReady,
  stopping,
  ttsPlaying,
  resuming,
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
    this.finalStatusWatchdogDuration = const Duration(milliseconds: 750),
    this.processingTimeoutDuration = const Duration(seconds: 12),
    this.ttsReadinessTimeout = const Duration(seconds: 5),
    this.ttsPlaybackTimeout = const Duration(seconds: 30),
    this.automaticRearmEnabled = true,
    this.listenButtonDebounce = const Duration(milliseconds: 350),
    this.postTtsAudioReleaseDelay = const Duration(milliseconds: 200),
    this.rearmRetryDelay = const Duration(milliseconds: 250),
  }) : _recognition = recognition;

  final ConversationRecognitionService _recognition;
  final ConversationSuggestionProvider responseEngine;
  final ConversationSemanticIntentClassifier semanticClassifier;
  final TranscriptNormalizer normalizer;
  final ConversationLanguageDetector languageDetector;
  final ConversationSpeechLogger logger;
  final Duration startupWatchdogDuration;
  final Duration finalStatusWatchdogDuration;
  final Duration processingTimeoutDuration;
  final Duration ttsReadinessTimeout;
  final Duration ttsPlaybackTimeout;
  final bool automaticRearmEnabled;
  final Duration listenButtonDebounce;
  final Duration postTtsAudioReleaseDelay;
  final Duration rearmRetryDelay;

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
  Timer? _finalStatusWatchdog;
  Timer? _processingWatchdog;
  int? _processingWatchdogTurnId;
  Future<void>? _recognitionCleanup;
  String? _recognitionLocale;
  String? _recognitionStrategy;
  String _nativeRecognitionStatus = 'IDLE';
  bool _listenModeEnabled = false;
  final Set<int> _ttsStartedTurns = <int>{};
  int? _autoTtsTurnId;
  int? _resumingFromTurnId;
  DateTime? _resumeRequestedAt;
  int? _activeCaptureTurnId;
  bool _lastResultWasFinal = false;
  bool _listenButtonTransitionLocked = false;
  DateTime? _lastListenButtonEventAt;
  int _listenButtonTransitionSequence = 0;
  Future<void>? _rearmOperation;
  Timer? _rearmDelayTimer;
  Completer<void>? _rearmDelayCompleter;
  int _rearmGeneration = 0;
  int _consecutiveRecognitionRecoveries = 0;

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
        ConversationSpeechState.speechDetected ||
        ConversationSpeechState.capturingUtterance ||
        ConversationSpeechState.finalizing => true,
        _ => false,
      };
  bool get listenModeActive => _listenModeEnabled;
  bool get listenButtonTransitionLocked => _listenButtonTransitionLocked;
  bool get recognitionSuppressed => _suppressRecognition;
  bool get autoSpeak => _autoSpeak;
  String get microphoneOwner =>
      _activeSessionId == null ? 'none' : 'SpeechRecognizer';
  bool get audioInputActive =>
      _activeSessionId != null &&
      _speechState != ConversationSpeechState.starting;
  bool get voiceDetected => _activeCaptureTurnId != null;
  String get partialTranscript => _lastResultWasFinal ? '' : _transcript;
  String get finalTranscript => _lastResultWasFinal ? _transcript : '';
  int get activeTurnId => _activeTurnId;
  int? get activeRecognitionSessionId => _activeSessionId;
  ConversationSpeechState get speechState => _speechState;
  String? get recognitionLocale => _recognitionLocale;
  String? get recognitionStrategy => _recognitionStrategy;
  String get nativeRecognitionStatus => _nativeRecognitionStatus;
  bool get _isKoreanRecognition {
    final locale = _recognitionLocale;
    if (locale != null &&
        locale.replaceAll('_', '-').toLowerCase().startsWith('ko-')) {
      return true;
    }
    return _effectiveInputLanguage(_outputLanguageMode) ==
        ConversationInputLanguage.korean;
  }

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

  Future<void> toggleListenMode({
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
    SpeechController? speechController,
    bool autoSpeak = false,
    LanguageMode outputLanguageMode = LanguageMode.bilingual,
    double speechRate = 0.5,
    bool japaneseTtsEnabled = true,
    bool koreanTtsEnabled = true,
  }) async {
    final now = DateTime.now();
    final previousEvent = _lastListenButtonEventAt;
    final delta = previousEvent == null
        ? null
        : now.difference(previousEvent).inMilliseconds;
    logger.ui(
      state: _listenModeEnabled ? 'ON' : 'OFF',
      event: 'pointer_press',
      details: <String, Object?>{
        'deltaMs': delta,
        'speechState': _speechState.name,
      },
    );
    if (_listenButtonTransitionLocked ||
        (delta != null && delta < listenButtonDebounce.inMilliseconds)) {
      logger.ui(
        state: _speechState.name.toUpperCase(),
        event: 'duplicate_press_ignored',
        details: <String, Object?>{'deltaMs': delta},
      );
      return;
    }
    _lastListenButtonEventAt = now;
    _listenButtonTransitionLocked = true;
    final transitionId = ++_listenButtonTransitionSequence;
    final starting = !_listenModeEnabled;
    logger.ui(
      state: starting ? 'OFF' : 'ON',
      event: starting ? 'START_accepted' : 'STOP_accepted',
      details: <String, Object?>{'transitionId': transitionId},
    );
    notifyListeners();
    try {
      if (starting) {
        await start(
          library: library,
          preferences: preferences,
          speechController: speechController,
          autoSpeak: autoSpeak,
          outputLanguageMode: outputLanguageMode,
          speechRate: speechRate,
          japaneseTtsEnabled: japaneseTtsEnabled,
          koreanTtsEnabled: koreanTtsEnabled,
        );
      } else {
        await stop();
      }
    } finally {
      _listenButtonTransitionLocked = false;
      logger.ui(
        state: _listenModeEnabled ? 'ON' : 'OFF',
        event: 'transition_complete',
        details: <String, Object?>{'transitionId': transitionId},
      );
      notifyListeners();
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
    if (_listenModeEnabled) {
      logger.event(
        sessionId: _activeSessionId ?? 0,
        state: _speechState.name.toUpperCase(),
        event: 'duplicate_start_ignored_session_already_enabled',
      );
      return;
    }
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
    _listenModeEnabled = true;
    final started = await _beginRecognitionSession(resumedFromTurnId: null);
    if (!started && _listenModeEnabled) {
      // The explicit Start command did not establish a session. This is not an
      // end-of-turn transition; return the failed command to OFF.
      _listenModeEnabled = false;
      notifyListeners();
    }
  }

  Future<bool> _beginRecognitionSession({
    required int? resumedFromTurnId,
  }) async {
    if (_closed || !_listenModeEnabled || _activeSessionId != null) {
      return false;
    }
    _transcript = '';
    _lastResultWasFinal = false;
    _confidence = 0;
    _errorMessage = null;
    _activeCaptureTurnId = null;
    final sessionId = ++_sessionSequence;
    _activeSessionId = sessionId;
    _recognitionLocale = null;
    _recognitionStrategy = null;
    _nativeRecognitionStatus = 'START_REQUESTED';
    final effectiveLanguage = _effectiveInputLanguage(_outputLanguageMode);
    logger.event(
      sessionId: sessionId,
      state: 'IDLE',
      event: resumedFromTurnId == null
          ? 'user_pressed_listen'
          : 'resume_listening_requested',
      details: <String, Object?>{
        'selectedInput': inputLanguage.name,
        'outputLanguageMode': _outputLanguageMode.name,
        'effectiveRecognitionMode': effectiveLanguage.name,
        'fromTurn': resumedFromTurnId,
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
      if (_activeSessionId != sessionId) return false;
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
      if (info.localeId.replaceAll('_', '-').toLowerCase().startsWith('ko-')) {
        logger.korean(
          turnId: 0,
          sessionId: sessionId,
          event: 'recognizer_configured',
          details: <String, Object?>{
            'mode': effectiveLanguage.name,
            'language': info.localeId,
            'startSuccess': true,
          },
        );
      }
      notifyListeners();
      return true;
    } on Object catch (error) {
      _startupWatchdog?.cancel();
      if (_activeSessionId != sessionId) return false;
      _activeSessionId = null;
      _errorMessage = '$error';
      logger.event(
        sessionId: sessionId,
        state: 'ERROR',
        event: 'recognition_start_failed',
        details: <String, Object?>{
          'message': error,
          'isRearm': resumedFromTurnId != null,
          'listenModeEnabled': _listenModeEnabled,
        },
      );
      _setSpeechState(
        ConversationSpeechState.error,
        sessionId,
        'start_failed',
      );
      _setPhase(ConversationAssistPhase.error);
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'start_failure_released_audio_owner',
        notify: false,
      );
      return false;
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

  /// Immediately invalidates and cancels the foreground Listen Mode session.
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
    final stoppedTurnId = _activeTurnId;
    logger.turn(
      turnId: stoppedTurnId,
      state: _speechState.name.toUpperCase(),
      event: 'STOP_PRESSED',
    );
    _listenModeEnabled = false;
    _cancelPendingRearm('stop_pressed');
    _resumingFromTurnId = null;
    _resumeRequestedAt = null;
    _startupWatchdog?.cancel();
    _finalStatusWatchdog?.cancel();
    _clearProcessingWatchdog();
    _activeSessionId = null;
    _activeTurnId = ++_turnSequence;
    _pendingVariantResult = null;
    _pendingVariantTurnId = null;
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
    _finalStatusWatchdog?.cancel();
    _clearProcessingWatchdog();
    _listenModeEnabled = false;
    _cancelPendingRearm('cancel_requested');
    _resumingFromTurnId = null;
    _resumeRequestedAt = null;
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
    logger.event(
      sessionId: _activeSessionId ?? 0,
      state: _speechState.name.toUpperCase(),
      event: 'audio_settings_applied',
      details: <String, Object?>{'autoSpeak': _autoSpeak},
    );
  }

  void setAutoSpeak(bool value) {
    logger.event(
      sessionId: _activeSessionId ?? 0,
      state: _speechState.name.toUpperCase(),
      event: 'auto_speak_ui_value_changed',
      details: <String, Object?>{'autoSpeak': value},
    );
    if (_autoSpeak == value) return;
    _autoSpeak = value;
    notifyListeners();
  }

  /// Runs a confirmed edit through the same finalized-turn pipeline. If Listen
  /// Mode is enabled, only the current recognizer turn is replaced and the
  /// persistent session is rearmed after manual processing.
  Future<bool> submitManualTranscript(
    String text, {
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
  }) async {
    final sessionId = _activeSessionId;
    final pendingRearm = _rearmOperation;
    _cancelPendingRearm('manual_transcript');
    if (pendingRearm != null) await pendingRearm;
    _startupWatchdog?.cancel();
    _finalStatusWatchdog?.cancel();
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
    if (_listenModeEnabled) {
      await _resumeListening(
        _activeTurnId,
        reason: 'manual_transcript_complete',
      );
    }
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
    int? assignedTurnId,
  }) async {
    final turnId = assignedTurnId ?? ++_turnSequence;
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
    final contextTimer = Stopwatch()..start();
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'buildConversationContext_START',
      details: <String, Object?>{'historyTurns': _history.length},
    );
    final withRecent = preferences.copyWith(
      recentLineIds: _recentLineIds.toSet(),
    );
    contextTimer.stop();
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'buildConversationContext_DONE',
      details: <String, Object?>{
        'durationMs': contextTimer.elapsedMilliseconds,
      },
    );
    final generationTimer = Stopwatch()..start();
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'generatePrimaryResponse_START',
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
      } on Object catch (error, stackTrace) {
        _errorMessage = 'Semantic classifier: $error';
        logger.turn(
          turnId: turnId,
          state: 'PROCESSING',
          event: 'semanticFallback_ERROR',
          details: <String, Object?>{
            'error': error,
            'stack': stackTrace,
          },
        );
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

    generationTimer.stop();
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'generatePrimaryResponse_DONE',
      details: <String, Object?>{
        'durationMs': generationTimer.elapsedMilliseconds,
        'relevant': relevant,
      },
    );

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
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'primaryResponse',
        details: <String, Object?>{
          'text': displayedResult.suggestions.first.line.japaneseText,
          'variantsPending': stageVariants,
        },
      );
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
    logger.turn(
      turnId: turnId,
      state: relevant ? 'PRIMARY_READY' : 'PROCESSING',
      event: 'response_UI_updated',
      details: <String, Object?>{'relevant': relevant},
    );
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
      ConversationSpeechState.capturingUtterance =>
        ConversationAssistPhase.capturingUtterance,
      ConversationSpeechState.finalizing =>
        ConversationAssistPhase.finalizing,
      ConversationSpeechState.processing =>
        ConversationAssistPhase.understanding,
      ConversationSpeechState.primaryReady =>
        ConversationAssistPhase.primaryReady,
      ConversationSpeechState.stopping => ConversationAssistPhase.stopping,
      ConversationSpeechState.ttsPlaying => ConversationAssistPhase.speaking,
      ConversationSpeechState.resuming => ConversationAssistPhase.resuming,
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
    _finalStatusWatchdog?.cancel();
    _activeSessionId = null;
    _nativeRecognitionStatus = 'TERMINAL';
    final turnId = _activeCaptureTurnId ?? ++_turnSequence;
    _activeCaptureTurnId = null;
    _activeTurnId = turnId;
    final turnTimer = Stopwatch()..start();
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'FINAL_TRANSCRIPT',
      details: <String, Object?>{
        'text': text.trim(),
        'confidence': _confidence,
      },
    );
    if (_isKoreanRecognition) {
      logger.korean(
        turnId: turnId,
        sessionId: sessionId,
        event: 'final_transcript',
        details: <String, Object?>{
          'mode': _effectiveInputLanguage(_outputLanguageMode).name,
          'language': _recognitionLocale,
          'finalTranscript': text.trim(),
          'accepted': text.trim().isNotEmpty,
        },
      );
    }
    _setSpeechState(
      ConversationSpeechState.processing,
      sessionId,
      'recognition_terminal',
    );
    _armProcessingWatchdog(turnId, sessionId);
    final finalizedText = text.trim();
    if (_effectiveInputLanguage(_outputLanguageMode) ==
        ConversationInputLanguage.both) {
      final detected = languageDetector.detect(finalizedText);
      logger.autoLanguage(
        turnId: turnId,
        event: 'primary_result',
        details: <String, Object?>{
          'selectedRecognitionLocale': _recognitionLocale,
          'detectedTranscriptScript': detected.name,
          'confidence': _confidence > 0 ? _confidence : 'unavailable',
          'primaryResult': finalizedText,
          'usable': finalizedText.isNotEmpty,
          'fallbackUsed': false,
          'fallbackAvailable': false,
          'fallbackReason': 'raw_audio_not_retained_by_speech_to_text',
        },
      );
    }
    try {
      if (finalizedText.isEmpty) {
        logger.turn(
          turnId: turnId,
          state: 'FINALIZING',
          event: 'empty_transcript_returning_to_wait',
        );
        if (_isKoreanRecognition) {
          _logKoreanTurnFailure(
            turnId,
            sessionId,
            'NO_FINAL_TRANSCRIPT',
          );
        }
        if (_listenModeEnabled) {
          await _resumeListening(turnId, reason: 'no_usable_transcript');
        } else {
          _setPhase(_result == null
              ? ConversationAssistPhase.noSpeech
              : ConversationAssistPhase.suggestions);
          _setSpeechState(
            ConversationSpeechState.idle,
            sessionId,
            'no_speech_complete',
          );
        }
        return;
      }
      if (_isKoreanRecognition) {
        logger.korean(
          turnId: turnId,
          sessionId: sessionId,
          event: 'response_generation_started',
          details: const <String, Object?>{'generationInvoked': true},
        );
      }
      final relevant = await onUtteranceFinalized(
        finalizedText,
        library: _library,
        preferences: preferences,
        source: FinalizedUtteranceSource.speech,
        transcriptionConfidence: _confidence,
        assignedTurnId: turnId,
      );
      if (_isKoreanRecognition) {
        logger.korean(
          turnId: turnId,
          sessionId: sessionId,
          event: 'response_generation_complete',
          details: <String, Object?>{
            'generationInvoked': true,
            'primaryReady': relevant,
            'intent': _activeIntentId,
          },
        );
      }
      if (!_isCurrentTurn(turnId) || _closed) {
        logger.turn(
          turnId: turnId,
          state: 'STALE',
          event: 'processing_result_ignored',
        );
        if (_isKoreanRecognition) {
          _logKoreanTurnFailure(turnId, sessionId, 'TURN_MARKED_STALE');
        }
        return;
      }
      _clearProcessingWatchdog(turnId);
      if (relevant) {
        _setSpeechState(
          ConversationSpeechState.primaryReady,
          sessionId,
          'primary_response_ready',
        );
        _setPhase(ConversationAssistPhase.primaryReady);
      }
      logger.turn(
        turnId: turnId,
        state: relevant ? 'PRIMARY_READY' : 'PROCESSING',
        event: 'autoSpeak_check',
        details: <String, Object?>{
          'autoSpeak': _autoSpeak,
          'primaryReady': relevant,
        },
      );
      if (!relevant && _isKoreanRecognition) {
        _logKoreanTurnFailure(
          turnId,
          sessionId,
          'RESPONSE_GENERATION_FAILED',
        );
      }
      if (relevant && _autoSpeak) {
        var ttsCompleted = false;
        if (_ttsStartedTurns.add(turnId)) {
          logger.turn(
            turnId: turnId,
            state: 'PRIMARY_READY',
            event: 'invoking_speakPrimary',
          );
          final speaking = _speakPrimarySuggestion(turnId, sessionId);
          await Future<void>.delayed(Duration.zero);
          _publishPendingVariantsSafely(turnId);
          ttsCompleted = await speaking;
          if (!ttsCompleted && _isKoreanRecognition) {
            _logKoreanTurnFailure(turnId, sessionId, 'TTS_FAILED');
          }
        } else {
          logger.turn(
            turnId: turnId,
            state: 'PRIMARY_READY',
            event: 'autoSpeak_skipped_ALREADY_STARTED',
          );
        }
        if (_isCurrentTurn(turnId) && _listenModeEnabled) {
          await _resumeListening(
            turnId,
            reason: ttsCompleted
                ? 'tts_completion'
                : 'tts_unavailable_or_failed',
            audioReleaseDelay:
                ttsCompleted ? postTtsAudioReleaseDelay : Duration.zero,
          );
        } else if (_isCurrentTurn(turnId)) {
          _setSpeechState(
            ConversationSpeechState.idle,
            sessionId,
            'tts_complete_session_stopped',
          );
          _setPhase(ConversationAssistPhase.suggestions);
        }
      } else {
        await Future<void>.delayed(Duration.zero);
        _publishPendingVariantsSafely(turnId);
        if (_listenModeEnabled) {
          await _resumeListening(
            turnId,
            reason: _autoSpeak
                ? 'no_primary_response'
                : 'auto_speak_off',
          );
        } else {
          _setSpeechState(
            ConversationSpeechState.idle,
            sessionId,
            'processing_complete_auto_speak_off',
          );
          _setPhase(_result == null
              ? ConversationAssistPhase.idle
              : ConversationAssistPhase.suggestions);
        }
      }
      logger.turn(
        turnId: turnId,
        state: _speechState.name.toUpperCase(),
        event: 'turn_complete',
        details: <String, Object?>{
          'durationMs': turnTimer.elapsedMilliseconds,
        },
      );
    } on Object catch (error, stackTrace) {
      logger.turn(
        turnId: turnId,
        state: _speechState.name.toUpperCase(),
        event: 'generatePrimaryResponse_ERROR',
        details: <String, Object?>{
          'error': error,
          'stack': stackTrace,
        },
      );
      if (_isKoreanRecognition) {
        _logKoreanTurnFailure(
          turnId,
          sessionId,
          'RESPONSE_GENERATION_FAILED',
        );
      }
      if (_isCurrentTurn(turnId)) {
        _errorMessage = "Couldn't generate a reply.";
        _setSpeechState(
          ConversationSpeechState.error,
          sessionId,
          'processing_error',
        );
        _setPhase(ConversationAssistPhase.error);
        if (_listenModeEnabled) {
          await _resumeListening(turnId, reason: 'processing_error');
        } else {
          _setSpeechState(
            ConversationSpeechState.idle,
            sessionId,
            'processing_error_idle',
          );
        }
      }
    } finally {
      _clearProcessingWatchdog(turnId);
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
    _lastResultWasFinal = isFinal;
    _confidence = confidence;
    _nativeRecognitionStatus = isFinal ? 'FINAL_RESULT' : 'PARTIAL_RESULT';
    if (_transcript.isNotEmpty && !isFinal) {
      if (_activeCaptureTurnId == null) {
        _ensureCaptureTurn(
          sessionId,
          source: 'native_partial_result',
        );
      }
      _setSpeechState(
        ConversationSpeechState.capturingUtterance,
        sessionId,
        'partial_transcript_capturing',
      );
      _setPhase(ConversationAssistPhase.capturingUtterance);
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
      if (_transcript.isNotEmpty) {
        if (_activeCaptureTurnId == null) {
          final turnId = _ensureCaptureTurn(
            sessionId,
            source: 'native_final_result',
          );
          if (_isKoreanRecognition) {
            logger.korean(
              turnId: turnId,
              sessionId: sessionId,
              event: 'speech_detected_from_final',
              details: const <String, Object?>{'speechDetected': true},
            );
          }
        }
      }
      // A final transcript is not the native terminal signal. Keep this
      // session token until `done`/`notListening` so the next tap cannot race
      // an Android recognizer that is still releasing its audio resources.
      _setSpeechState(
        ConversationSpeechState.finalizing,
        sessionId,
        'final_waiting_for_terminal_status',
      );
      _setPhase(ConversationAssistPhase.finalizing);
      _armFinalStatusWatchdog(sessionId);
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
      _consecutiveRecognitionRecoveries = 0;
      logger.turn(
        turnId: _resumingFromTurnId ?? _activeTurnId,
        state: 'READY_FOR_SPEECH',
        event: 'rearm_audio_verified',
        details: <String, Object?>{
          'vadArmed': false,
          'nativeRecognizerOwnsTurnEnd': true,
          'microphoneActive': true,
          'recognizerReady': true,
          'locale': _recognitionLocale,
        },
      );
      if (_isKoreanRecognition) {
        logger.korean(
          turnId: _activeCaptureTurnId ?? 0,
          sessionId: sessionId,
          event: 'recognizer_ready',
          details: <String, Object?>{
            'ready': true,
            'language': _recognitionLocale ?? 'ko-KR requested',
          },
        );
      }
      final resumeTurnId = _resumingFromTurnId;
      final requestedAt = _resumeRequestedAt;
      if (resumeTurnId != null && requestedAt != null) {
        logger.turn(
          turnId: resumeTurnId,
          state: 'READY_FOR_SPEECH',
          event: 'listener_ready_after_resume',
          details: <String, Object?>{
            'durationMs': DateTime.now().difference(requestedAt).inMilliseconds,
          },
        );
        _resumingFromTurnId = null;
        _resumeRequestedAt = null;
      }
      return;
    }
    notifyListeners();
  }

  int _ensureCaptureTurn(int sessionId, {required String source}) {
    final existing = _activeCaptureTurnId;
    if (existing != null) return existing;
    final turnId = ++_turnSequence;
    _activeTurnId = turnId;
    _activeCaptureTurnId = turnId;
    logger.turn(
      turnId: turnId,
      state: 'SPEECH_DETECTED',
      event: 'automatic_turn_created',
      details: <String, Object?>{
        'sessionId': sessionId,
        'source': source,
      },
    );
    return turnId;
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
      _finalStatusWatchdog?.cancel();
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
    final wasEstablishedTurn =
        _speechState != ConversationSpeechState.starting;
    _startupWatchdog?.cancel();
    _finalStatusWatchdog?.cancel();
    _activeSessionId = null;
    _nativeRecognitionStatus = 'ERROR';
    final normalized = message.toLowerCase();
    _errorMessage = message;
    final permission = normalized.contains('permission') ||
        normalized.contains('notallowed');
    final recoverablePlatformError =
        !permission && platformCode != 12 && platformCode != 13;
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
    if (_isKoreanRecognition) {
      final failureReason = platformCode == 6
          ? 'NO_SPEECH_DETECTED'
          : platformCode == 7
              ? 'NO_FINAL_TRANSCRIPT'
              : 'RECOGNITION_ERROR_${platformCode ?? 'UNKNOWN'}';
      _logKoreanTurnFailure(
        _activeCaptureTurnId ?? _activeTurnId,
        sessionId,
        failureReason,
      );
    }
    _recoverFromRecognitionError(
      sessionId,
      event: 'recognition_error_complete',
      phase: permission
          ? ConversationAssistPhase.permissionDenied
          : ConversationAssistPhase.error,
      automaticallyRearm: recoverablePlatformError && wasEstablishedTurn,
    );
  }

  Future<bool> _speakPrimarySuggestion(int turnId, int sessionId) async {
    final speech = _speechController;
    final suggestions = _result?.suggestions;
    if (!_isCurrentTurn(turnId)) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'autoSpeak_skipped_TURN_NO_LONGER_ACTIVE',
      );
      return false;
    }
    if (speech == null || !speech.isSupported) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'autoSpeak_skipped_TTS_NOT_SUPPORTED',
      );
      return false;
    }
    if (suggestions == null || suggestions.isEmpty) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'autoSpeak_skipped_PRIMARY_EMPTY',
      );
      return false;
    }
    final line = suggestions.first.line;
    final useKorean = _outputLanguageMode == LanguageMode.korean;
    final visibleText = useKorean ? line.koreanText ?? '' : line.japaneseText;
    final sanitizedText = const TtsTextSanitizer().sanitize(visibleText);
    logger.turn(
      turnId: turnId,
      state: 'PRIMARY_READY',
      event: 'TTS_input',
      details: <String, Object?>{
        'visibleResponse': visibleText,
        'sanitizedResponse': sanitizedText,
      },
    );
    if (sanitizedText.isEmpty) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'autoSpeak_skipped_TTS_TEXT_EMPTY',
      );
      return false;
    }
    if ((useKorean && (!_koreanTtsEnabled || !line.ttsKorean)) ||
        (!useKorean && (!_japaneseTtsEnabled || !line.ttsJapanese))) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'autoSpeak_skipped_TTS_DISABLED_FOR_RESPONSE',
      );
      return false;
    }
    bool ready;
    try {
      ready = await (useKorean
              ? speech.ensureKoreanChecked()
              : speech.ensureJapaneseChecked())
          .timeout(ttsReadinessTimeout);
    } on TimeoutException {
      ready = false;
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: 'TTS_READINESS_TIMEOUT',
        details: <String, Object?>{
          'timeoutMs': ttsReadinessTimeout.inMilliseconds,
        },
      );
    }
    logger.turn(
      turnId: turnId,
      state: 'PRIMARY_READY',
      event: 'TTS_ready',
      details: <String, Object?>{'ready': ready},
    );
    if (!ready || !_isCurrentTurn(turnId)) {
      logger.turn(
        turnId: turnId,
        state: 'PRIMARY_READY',
        event: !ready
            ? 'autoSpeak_skipped_TTS_NOT_READY'
            : 'autoSpeak_skipped_TURN_NO_LONGER_ACTIVE',
      );
      return false;
    }
    _suppressRecognition = true;
    _autoTtsTurnId = turnId;
    _setSpeechState(
      ConversationSpeechState.ttsPlaying,
      sessionId,
      'tts_start',
    );
    _setPhase(ConversationAssistPhase.speaking);
    final ttsTimer = Stopwatch()..start();
    logger.turn(
      turnId: turnId,
      state: 'TTS_PLAYING',
      event: 'TTS_speak_requested',
    );
    if (_isKoreanRecognition) {
      logger.korean(
        turnId: turnId,
        sessionId: sessionId,
        event: 'tts_invoked',
        details: <String, Object?>{
          'ttsInvoked': true,
          'outputLanguage': useKorean ? 'ko-KR' : 'ja-JP',
        },
      );
    }
    try {
      if (useKorean) {
        await speech.toggleKorean(
          lineId: line.id,
          koreanText: visibleText,
          rate: _speechRate,
          turnId: turnId,
        ).timeout(ttsPlaybackTimeout);
      } else {
        await speech.toggleJapanese(
          lineId: line.id,
          japaneseText: visibleText,
          rate: _speechRate,
          turnId: turnId,
        ).timeout(ttsPlaybackTimeout);
      }
      final playbackError = speech.lastError;
      if (playbackError != null) {
        logger.turn(
          turnId: turnId,
          state: 'TTS_PLAYING',
          event: 'TTS_ERROR',
          details: <String, Object?>{'error': playbackError},
        );
        return false;
      }
      logger.turn(
        turnId: turnId,
        state: 'TTS_PLAYING',
        event: 'TTS_onDone',
        details: <String, Object?>{
          'durationMs': ttsTimer.elapsedMilliseconds,
        },
      );
      return true;
    } on TimeoutException {
      logger.turn(
        turnId: turnId,
        state: 'TTS_PLAYING',
        event: 'TTS_COMPLETION_TIMEOUT',
        details: <String, Object?>{
          'timeoutMs': ttsPlaybackTimeout.inMilliseconds,
        },
      );
      await speech.stop();
      return false;
    } finally {
      _autoTtsTurnId = null;
      _suppressRecognition = false;
      if (_isCurrentTurn(turnId)) {
        _setSpeechState(
          ConversationSpeechState.primaryReady,
          sessionId,
          'tts_complete',
        );
        _setPhase(ConversationAssistPhase.primaryReady);
      }
    }
  }

  Future<void> _resumeListening(
    int turnId, {
    required String reason,
    Duration audioReleaseDelay = Duration.zero,
  }) {
    if (!automaticRearmEnabled) {
      _finishManualRecognitionTurn(turnId, reason: reason);
      return Future<void>.value();
    }
    return _armNextConversationTurn(
      turnId,
      reason: reason,
      audioReleaseDelay: audioReleaseDelay,
    );
  }

  void _finishManualRecognitionTurn(
    int turnId, {
    required String reason,
  }) {
    if (_closed || !_isCurrentTurn(turnId)) return;
    _listenModeEnabled = false;
    _resumingFromTurnId = null;
    _resumeRequestedAt = null;
    _cancelPendingRearm('manual_stt_repair_complete');
    logger.turn(
      turnId: turnId,
      state: _speechState.name.toUpperCase(),
      event: 'manual_STT_turn_complete_no_rearm',
      details: <String, Object?>{'reason': reason},
    );
    _setSpeechState(
      ConversationSpeechState.idle,
      _activeSessionId ?? 0,
      'manual_turn_returned_to_idle',
      notify: false,
    );
    if (_phase != ConversationAssistPhase.error &&
        _phase != ConversationAssistPhase.permissionDenied &&
        _phase != ConversationAssistPhase.unavailable) {
      _setPhase(_result == null
          ? (_transcript.trim().isEmpty
              ? ConversationAssistPhase.noSpeech
              : ConversationAssistPhase.idle)
          : ConversationAssistPhase.suggestions);
    } else {
      notifyListeners();
    }
  }

  /// Rearms one native recognizer session inside the still-enabled Listen Mode
  /// session. Android recognition is one-shot, so this recreates only the
  /// per-turn recognizer; conversation history and all session settings remain.
  Future<void> _armNextConversationTurn(
    int turnId, {
    required String reason,
    required Duration audioReleaseDelay,
  }) {
    final existing = _rearmOperation;
    if (existing != null) {
      logger.turn(
        turnId: turnId,
        state: _speechState.name.toUpperCase(),
        event: 'armNextConversationTurn_duplicate_ignored',
        details: <String, Object?>{'reason': reason},
      );
      return existing;
    }
    final generation = ++_rearmGeneration;
    final operation = _performRearm(
      turnId,
      reason: reason,
      audioReleaseDelay: audioReleaseDelay,
      generation: generation,
    );
    _rearmOperation = operation;
    return operation.whenComplete(() {
      if (identical(_rearmOperation, operation)) _rearmOperation = null;
    });
  }

  Future<void> _performRearm(
    int turnId, {
    required String reason,
    required Duration audioReleaseDelay,
    required int generation,
  }) async {
    if (_closed || !_listenModeEnabled || !_isCurrentTurn(turnId)) {
      logger.turn(
        turnId: turnId,
        state: _speechState.name.toUpperCase(),
        event: 'armNextConversationTurn_skipped',
        details: <String, Object?>{
          'listenModeEnabled': _listenModeEnabled,
          'currentTurn': _isCurrentTurn(turnId),
        },
      );
      return;
    }
    logger.turn(
      turnId: turnId,
      state: 'RESUMING',
      event: 'scheduling_rearm',
      details: <String, Object?>{
        'reason': reason,
        'listenModeEnabled': _listenModeEnabled,
        'audioReleaseDelayMs': audioReleaseDelay.inMilliseconds,
      },
    );
    _resumingFromTurnId = turnId;
    _resumeRequestedAt = DateTime.now();
    _setSpeechState(
      ConversationSpeechState.resuming,
      0,
      'resume_requested',
    );
    _setPhase(ConversationAssistPhase.resuming);

    for (var attempt = 1; attempt <= 2; attempt++) {
      final delay = attempt == 1 ? audioReleaseDelay : rearmRetryDelay;
      if (delay > Duration.zero) {
        logger.turn(
          turnId: turnId,
          state: 'RESUMING',
          event: 'audio_release_delay',
          details: <String, Object?>{
            'delayMs': delay.inMilliseconds,
            'attempt': attempt,
          },
        );
        await _waitForRearmDelay(delay);
      }
      if (_closed ||
          !_listenModeEnabled ||
          !_isCurrentTurn(turnId) ||
          generation != _rearmGeneration) {
        logger.turn(
          turnId: turnId,
          state: _speechState.name.toUpperCase(),
          event: 'rearm_cancelled_before_start',
          details: <String, Object?>{'attempt': attempt},
        );
        return;
      }
      logger.turn(
        turnId: turnId,
        state: 'RESUMING',
        event: 'armNextConversationTurn',
        details: <String, Object?>{'attempt': attempt},
      );
      final started =
          await _beginRecognitionSession(resumedFromTurnId: turnId);
      if (started) {
        logger.turn(
          turnId: turnId,
          state: 'STARTING',
          event: 'recognizer_rearm_start_accepted',
          details: <String, Object?>{
            'attempt': attempt,
            'microphoneActive': false,
            'waitingForNativeAudioCallback': true,
          },
        );
        return;
      }
    }
    logger.turn(
      turnId: turnId,
      state: 'ERROR',
      event: 'rearm_failed_after_bounded_retry',
      details: <String, Object?>{
        'listenModeEnabled': _listenModeEnabled,
        'attempts': 2,
      },
    );
  }

  Future<void> _waitForRearmDelay(Duration delay) {
    final completer = Completer<void>();
    _rearmDelayCompleter = completer;
    _rearmDelayTimer = Timer(delay, () {
      if (!completer.isCompleted) completer.complete();
      if (identical(_rearmDelayCompleter, completer)) {
        _rearmDelayCompleter = null;
        _rearmDelayTimer = null;
      }
    });
    return completer.future;
  }

  void _cancelPendingRearm(String reason) {
    _rearmGeneration++;
    _rearmOperation = null;
    _rearmDelayTimer?.cancel();
    _rearmDelayTimer = null;
    final completer = _rearmDelayCompleter;
    _rearmDelayCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    logger.turn(
      turnId: _activeTurnId,
      state: _speechState.name.toUpperCase(),
      event: 'pending_rearm_cancelled',
      details: <String, Object?>{'reason': reason},
    );
  }

  void _logKoreanTurnFailure(
    int turnId,
    int sessionId,
    String reason,
  ) {
    logger.korean(
      turnId: turnId,
      sessionId: sessionId,
      event: 'KOREAN_TURN_FAILED',
      details: <String, Object?>{'reason': reason},
    );
  }

  void _armProcessingWatchdog(int turnId, int sessionId) {
    _processingWatchdog?.cancel();
    _processingWatchdogTurnId = turnId;
    _processingWatchdog = Timer(processingTimeoutDuration, () {
      if (_closed ||
          !_isCurrentTurn(turnId) ||
          _speechState != ConversationSpeechState.processing) {
        return;
      }
      unawaited(_handleProcessingTimeout(turnId, sessionId));
    });
  }

  void _clearProcessingWatchdog([int? turnId]) {
    if (turnId != null && _processingWatchdogTurnId != turnId) return;
    _processingWatchdog?.cancel();
    _processingWatchdog = null;
    _processingWatchdogTurnId = null;
  }

  Future<void> _handleProcessingTimeout(int turnId, int sessionId) async {
    if (!_isCurrentTurn(turnId) ||
        _speechState != ConversationSpeechState.processing) {
      return;
    }
    logger.turn(
      turnId: turnId,
      state: 'PROCESSING',
      event: 'PROCESSING_TIMEOUT',
      details: <String, Object?>{
        'timeoutMs': processingTimeoutDuration.inMilliseconds,
      },
    );
    _clearProcessingWatchdog(turnId);
    _pendingVariantResult = null;
    _pendingVariantTurnId = null;
    _activeTurnId = ++_turnSequence;
    _errorMessage = "Couldn't generate a reply.";
    _setSpeechState(
      ConversationSpeechState.error,
      sessionId,
      'processing_timeout',
    );
    _setPhase(ConversationAssistPhase.error);
    if (_listenModeEnabled) {
      final recoveryTurnId = _activeTurnId;
      await _resumeListening(recoveryTurnId, reason: 'processing_timeout');
    } else {
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'processing_timeout_idle',
      );
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

  void _publishPendingVariantsSafely(int turnId) {
    try {
      _publishPendingVariants(turnId);
    } on Object catch (error, stackTrace) {
      logger.turn(
        turnId: turnId,
        state: _speechState.name.toUpperCase(),
        event: 'secondaryVariants_ERROR',
        details: <String, Object?>{
          'error': error,
          'stack': stackTrace,
        },
      );
    }
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
      if (_autoTtsTurnId != null) return;
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
    required bool automaticallyRearm,
  }) {
    _resumingFromTurnId = null;
    _resumeRequestedAt = null;
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
    if (!automaticRearmEnabled) {
      _listenModeEnabled = false;
      notifyListeners();
      return;
    }
    if (!_listenModeEnabled || !automaticallyRearm) return;
    if (_consecutiveRecognitionRecoveries >= 1) {
      logger.turn(
        turnId: _activeTurnId,
        state: 'ERROR',
        event: 'recognition_recovery_exhausted',
        details: const <String, Object?>{'attempts': 1},
      );
      return;
    }
    _consecutiveRecognitionRecoveries++;
    final recoveryTurnId = _activeCaptureTurnId ?? ++_turnSequence;
    _activeCaptureTurnId = null;
    _activeTurnId = recoveryTurnId;
    unawaited(_resumeListening(
      recoveryTurnId,
      reason: 'recognition_error_recovery',
      audioReleaseDelay: rearmRetryDelay,
    ));
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
      final recoveryTurnId = _resumingFromTurnId ?? _activeTurnId;
      _activeSessionId = null;
      _nativeRecognitionStatus = 'STARTUP_STALLED';
      _errorMessage = 'Speech recognizer did not activate. Please try again.';
      _setSpeechState(
        ConversationSpeechState.error,
        sessionId,
        'startup_watchdog_failed',
      );
      _setPhase(ConversationAssistPhase.error);
      if (!automaticRearmEnabled) {
        _listenModeEnabled = false;
        notifyListeners();
      }
      unawaited(_cancelStalledSession(sessionId).then((_) async {
        if (!_listenModeEnabled || _closed) return;
        if (_consecutiveRecognitionRecoveries >= 1) {
          logger.turn(
            turnId: recoveryTurnId,
            state: 'ERROR',
            event: 'startup_recovery_exhausted',
            details: const <String, Object?>{'attempts': 1},
          );
          return;
        }
        _consecutiveRecognitionRecoveries++;
        await _resumeListening(
          recoveryTurnId,
          reason: 'startup_watchdog_recovery',
          audioReleaseDelay: rearmRetryDelay,
        );
      }));
      _setSpeechState(
        ConversationSpeechState.idle,
        sessionId,
        'startup_watchdog_returned_to_idle',
        notify: false,
      );
    });
  }

  /// A native final transcript normally arrives immediately before the
  /// recognizer's terminal status. Some Android recognizers occasionally omit
  /// that last status callback, which used to leave a visible transcript stuck
  /// in FINALIZING forever. Give the provider time to finish naturally, then
  /// ask it to release the microphone. Response generation still starts only
  /// after the recognizer has relinquished audio ownership.
  void _armFinalStatusWatchdog(int sessionId) {
    _finalStatusWatchdog?.cancel();
    _finalStatusWatchdog = Timer(finalStatusWatchdogDuration, () {
      if (_closed ||
          _activeSessionId != sessionId ||
          _speechState != ConversationSpeechState.finalizing) {
        return;
      }
      logger.event(
        sessionId: sessionId,
        state: 'FINALIZING',
        event: 'terminal_status_watchdog_fired',
      );
      unawaited(_releaseFinalizedRecognitionSession(sessionId));
    });
  }

  Future<void> _releaseFinalizedRecognitionSession(int sessionId) async {
    try {
      await _recognition
          .stop(sessionId: sessionId)
          .timeout(const Duration(seconds: 2));
      // Platform stop futures may finish just before their status callback.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (_activeSessionId != sessionId || _closed) return;
      logger.event(
        sessionId: sessionId,
        state: 'FINALIZING',
        event: 'terminal_status_still_missing_after_stop',
      );
      await _recognition
          .cancel(sessionId: sessionId)
          .timeout(const Duration(seconds: 2));
      if (_activeSessionId == sessionId && !_closed) {
        await _completeSpeechSession(sessionId, _transcript);
      }
    } on Object catch (error) {
      if (_activeSessionId != sessionId || _closed) return;
      _errorMessage = '$error';
      logger.event(
        sessionId: sessionId,
        state: 'ERROR',
        event: 'finalized_session_release_failed',
        details: <String, Object?>{'message': error},
      );
      _activeSessionId = null;
      _recoverFromRecognitionError(
        sessionId,
        event: 'finalized_session_release_error',
        phase: ConversationAssistPhase.error,
        automaticallyRearm: false,
      );
    }
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
    final previous = _speechState;
    _speechState = value;
    logger.event(
      sessionId: sessionId,
      state: value.name.toUpperCase(),
      event: event,
      details: <String, Object?>{
        'transition':
            '${previous.name.toUpperCase()}->${value.name.toUpperCase()}',
      },
    );
    _logIllegalStateIfNeeded(sessionId);
    if (notify) notifyListeners();
  }

  void _logIllegalStateIfNeeded(int sessionId) {
    final needsSession = _speechState == ConversationSpeechState.starting ||
        _speechState == ConversationSpeechState.readyForSpeech ||
        _speechState == ConversationSpeechState.speechDetected ||
        _speechState == ConversationSpeechState.capturingUtterance ||
        _speechState == ConversationSpeechState.finalizing;
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
    _finalStatusWatchdog?.cancel();
    _processingWatchdog?.cancel();
    _speechController?.removeListener(_onSpeechStateChanged);
    _speechController?.setPlaybackGuard(null);
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cancelPendingRearm('controller_closed');
    _startupWatchdog?.cancel();
    _finalStatusWatchdog?.cancel();
    _processingWatchdog?.cancel();
    _listenModeEnabled = false;
    _activeSessionId = null;
    _speechController?.removeListener(_onSpeechStateChanged);
    _speechController?.setPlaybackGuard(null);
    final cleanup = _recognitionCleanup;
    if (cleanup != null) await cleanup;
    await _recognition.dispose();
  }
}
