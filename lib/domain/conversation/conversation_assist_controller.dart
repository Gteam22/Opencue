import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/opener_line.dart';
import 'conversation_models.dart';
import 'conversation_recognition_service.dart';
import 'conversation_response_engine.dart';
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
    VoiceActivityTracker? voiceActivity,
  })  : _recognition = recognition,
        voiceActivity = voiceActivity ?? VoiceActivityTracker();

  final ConversationRecognitionService _recognition;
  final ConversationSuggestionProvider responseEngine;
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
  Timer? _vadTimer;
  bool _initialized = false;
  bool _finalizing = false;
  double? _sourceConfidence;
  bool _closed = false;
  DateTime? _listeningStartedAt;

  static const Duration noSpeechTimeout = Duration(seconds: 8);

  ConversationAssistPhase get phase => _phase;
  String get transcript => _transcript;
  String? get errorMessage => _errorMessage;
  double get confidence => _confidence;
  double get soundLevel => _soundLevel;
  ConversationSuggestionResult? get result => _result;
  List<ConversationTurn> get history => List.unmodifiable(_history);
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
    _result = null;
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
    if (!isListening) return;
    _vadTimer?.cancel();
    await _recognition.stop();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (_phase == ConversationAssistPhase.listening) {
      await _finalizeTranscript();
    }
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
    if (_transcript.trim().isNotEmpty && _library.isNotEmpty) {
      suggestFromText(
        _transcript,
        library: _library,
        preferences: value,
        recordTurn: false,
        transcriptionConfidence: _sourceConfidence,
      );
    }
  }

  void suggestFromText(
    String text, {
    required List<OpenerLine> library,
    required ConversationPreferences preferences,
    bool recordTurn = true,
    double? transcriptionConfidence,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      _transcript = '';
      _result = null;
      _setPhase(ConversationAssistPhase.noSpeech);
      return;
    }
    _library = library;
    this.preferences = preferences;
    if (recordTurn) _sourceConfidence = transcriptionConfidence;
    _transcript = trimmed;
    _setPhase(ConversationAssistPhase.understanding);
    final withRecent = preferences.copyWith(
      recentLineIds: _recentLineIds.toSet(),
    );
    _result = responseEngine.suggest(
      transcript: trimmed,
      library: library,
      preferences: withRecent,
      history: _history,
      transcriptionConfidence: transcriptionConfidence ?? _sourceConfidence,
    );
    final ids = _result!.suggestions.map((item) => item.line.id);
    _remember(ids);
    if (recordTurn) {
      _history.insert(
        0,
        ConversationTurn(
          transcript: trimmed,
          language: _result!.interpretation.language,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      if (_history.length > 5) _history.removeRange(5, _history.length);
    }
    _setPhase(ConversationAssistPhase.suggestions);
  }

  void more() {
    if (_transcript.isEmpty || _library.isEmpty) return;
    suggestFromText(
      _transcript,
      library: _library,
      preferences: preferences,
      recordTurn: false,
      transcriptionConfidence: _sourceConfidence,
    );
  }

  Future<void> _finalizeTranscript() async {
    if (_finalizing) return;
    _finalizing = true;
    _vadTimer?.cancel();
    if (_transcript.trim().isEmpty) {
      _setPhase(ConversationAssistPhase.noSpeech);
    } else {
      suggestFromText(
        _transcript,
        library: _library,
        preferences: preferences,
        transcriptionConfidence: _confidence,
      );
    }
    _finalizing = false;
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
