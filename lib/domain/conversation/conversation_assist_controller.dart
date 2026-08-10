import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/opener_line.dart';
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
  listening,
  understanding,
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
  bool _initialized = false;
  bool _finalizing = false;
  double? _sourceConfidence;
  bool _closed = false;
  DateTime? _listeningStartedAt;
  ConversationPipelineDiagnostics? _diagnostics;
  String? _lastFinalizedNormalized;
  DateTime? _lastFinalizedAt;
  String? _activeCueTranscript;
  int _cueRevision = 0;

  static const Duration noSpeechTimeout = Duration(seconds: 10);
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
  bool get isListening => _phase == ConversationAssistPhase.listening;

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
  }) async {
    if (!_initialized) await prepare();
    if (!_initialized) return;
    _library = library;
    this.preferences = preferences;
    _transcript = '';
    _confidence = 0;
    _errorMessage = null;
    _finalizing = false;
    voiceActivity.reset();
    _listeningStartedAt = DateTime.now();
    _setPhase(ConversationAssistPhase.listening);
    try {
      await _recognition.start(language: inputLanguage);
      _vadTimer?.cancel();
      _vadTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        final now = DateTime.now();
        final noSpeechTimedOut = !voiceActivity.heardSpeech &&
            _listeningStartedAt != null &&
            now.difference(_listeningStartedAt!) >= noSpeechTimeout;
        if (isListening &&
            (voiceActivity.shouldStop(now) || noSpeechTimedOut)) {
          unawaited(stop());
        }
      });
    } on Object catch (error) {
      _errorMessage = '$error';
      _setPhase(ConversationAssistPhase.error);
    }
  }

  Future<void> stop() async {
    if (!isListening || _finalizing) return;
    await _finalizeTranscript();
  }

  Future<void> cancel() async {
    _vadTimer?.cancel();
    await _recognition.cancel();
    _setPhase(ConversationAssistPhase.idle);
  }

  void setInputLanguage(ConversationInputLanguage value) {
    inputLanguage = value;
    notifyListeners();
  }

  void setPreferences(ConversationPreferences value) {
    preferences = value;
    notifyListeners();
    _rerankActiveCue();
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

    final intentId = relevant
        ? nextResult.interpretation.primaryIntentId!
        : 'unknown';
    _recordTurn(
      transcript: trimmed,
      language: nextResult.interpretation.language,
      intentId: relevant ? intentId : null,
      confidence: nextResult.interpretation.intentConfidence,
      createdAt: now,
    );
    if (relevant) {
      _result = nextResult;
      _activeCueTranscript = trimmed;
      _sourceConfidence = transcriptionConfidence;
      _cueRevision++;
      final ids = nextResult.suggestions.map((item) => item.line.id);
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
    );
    _setPhase(_result == null
        ? ConversationAssistPhase.idle
        : ConversationAssistPhase.suggestions);
    return relevant;
  }

  void more() {
    _rerankActiveCue();
  }

  void _rerankActiveCue() {
    final active = _activeCueTranscript;
    if (active == null || active.isEmpty || _library.isEmpty) return;
    final next = responseEngine.suggest(
      transcript: active,
      library: _library,
      preferences: preferences.copyWith(
        recentLineIds: _recentLineIds.toSet(),
      ),
      history: _history,
      transcriptionConfidence: _sourceConfidence,
    );
    if (!_isRelevant(next)) return;
    _result = next;
    _cueRevision++;
    final ids = next.suggestions.map((item) => item.line.id);
    _remember(ids);
    for (final id in ids) {
      _recordFeedback(id, SuggestionFeedbackKind.shown);
    }
    _setPhase(ConversationAssistPhase.suggestions);
  }

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
  }) {
    _history.insert(
      0,
      ConversationTurn(
        id: 'turn-${createdAt.microsecondsSinceEpoch}-${_history.length}',
        transcript: transcript,
        language: language,
        createdAt: createdAt,
        detectedIntent: intentId,
        confidence: confidence,
      ),
    );
    if (_history.length > 6) _history.removeRange(6, _history.length);
  }

  SuggestionFeedbackKind? feedbackFor(String lineId) =>
      _latestFeedback[lineId];

  void acceptSuggestion(String lineId) {
    if (_latestFeedback[lineId] == SuggestionFeedbackKind.accepted) return;
    _recordFeedback(lineId, SuggestionFeedbackKind.accepted);
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

  Future<void> _finalizeTranscript() async {
    if (_finalizing) return;
    _finalizing = true;
    _vadTimer?.cancel();
    try {
      await _recognition.stop();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await onUtteranceFinalized(
        _transcript,
        library: _library,
        preferences: preferences,
        source: FinalizedUtteranceSource.speech,
        transcriptionConfidence: _confidence,
      );
    } on Object catch (error) {
      _errorMessage = '$error';
      _setPhase(ConversationAssistPhase.error);
    } finally {
      _finalizing = false;
    }
  }

  void _onRecognitionResult(String text, bool isFinal, double confidence) {
    if (text.trim().isNotEmpty) _transcript = text.trim();
    _confidence = confidence;
    notifyListeners();
    if (isFinal && isListening) unawaited(_finalizeTranscript());
  }

  void _onSoundLevel(double level) {
    _soundLevel = level;
    voiceActivity.addLevel(level, DateTime.now());
    notifyListeners();
  }

  void _onStatus(String status) {
    if ((status == 'done' || status == 'notListening') && isListening) {
      unawaited(_finalizeTranscript());
    }
  }

  void _onRecognitionError(String message, {required bool permanent}) {
    _vadTimer?.cancel();
    _errorMessage = message;
    final normalized = message.toLowerCase();
    if (normalized.contains('no_match') ||
        normalized.contains('speech_timeout')) {
      _setPhase(ConversationAssistPhase.noSpeech);
      return;
    }
    final permission = normalized.contains('permission') ||
        normalized.contains('notallowed');
    _setPhase(permission
        ? ConversationAssistPhase.permissionDenied
        : ConversationAssistPhase.error);
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
    unawaited(close());
    super.dispose();
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _vadTimer?.cancel();
    await _recognition.dispose();
  }
}
