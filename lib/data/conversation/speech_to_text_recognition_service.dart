import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/conversation/conversation_models.dart';
import '../../domain/conversation/conversation_recognition_service.dart';
import '../../domain/conversation/conversation_speech_log.dart';

/// Adapter over the platform speech recognizer. It receives transcript events
/// only; OpenCue never creates or retains an audio recording.
class SpeechToTextRecognitionService
    implements ConversationRecognitionService {
  SpeechToTextRecognitionService({
    SpeechToText? speech,
    ConversationSpeechLogger logger = const ConversationSpeechLogger(),
  })  : _speech = speech ?? SpeechToText(),
        _logger = logger;

  final SpeechToText _speech;
  final ConversationSpeechLogger _logger;
  ConversationRecognitionCallbacks? _callbacks;
  bool _available = false;
  int? _activeSessionId;
  Future<bool>? _initializeFuture;

  @override
  bool get isSupported => _available;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) {
    _callbacks = callbacks;
    return _initializeFuture ??= _initializeOnce();
  }

  Future<bool> _initializeOnce() async {
    _logger.event(sessionId: 0, state: 'INITIALIZING', event: 'initialize');
    _available = await _speech.initialize(
      debugLogging: true,
      finalTimeout: const Duration(seconds: 2),
      options: <SpeechConfigOption>[SpeechToText.androidNoBluetooth],
      onStatus: _onStatus,
      onError: _onError,
    );
    _logger.event(
      sessionId: 0,
      state: _available ? 'IDLE' : 'ERROR',
      event: 'initialize_complete',
      details: <String, Object?>{'available': _available},
    );
    return _available;
  }

  @override
  Future<void> start({
    required int sessionId,
    required ConversationInputLanguage language,
  }) async {
    if (!_available || _callbacks == null) {
      throw StateError('Speech recognition is not available.');
    }
    if (_activeSessionId != null || _speech.isListening) {
      _logger.event(
        sessionId: sessionId,
        state: 'ERROR',
        event: 'start_rejected_busy',
        details: <String, Object?>{'activeSession': _activeSessionId},
      );
      throw StateError('Speech recognizer is already active.');
    }
    final locale = await _localeFor(language);
    _activeSessionId = sessionId;
    _logger.event(
      sessionId: sessionId,
      state: 'LISTENING',
      event: 'listen_requested',
      details: <String, Object?>{'locale': locale},
    );
    try {
      await _speech.listen(
        onResult: (result) => _onResult(sessionId, result),
        onSoundLevelChange: (level) => _onSoundLevel(sessionId, level),
        localeId: locale,
        listenFor: const Duration(seconds: 55),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        onDevice: false,
        listenMode: ListenMode.dictation,
      );
    } on Object catch (error) {
      if (_activeSessionId == sessionId) _activeSessionId = null;
      _logger.event(
        sessionId: sessionId,
        state: 'ERROR',
        event: 'listen_failed',
        details: <String, Object?>{'message': error},
      );
      rethrow;
    }
  }

  Future<String?> _localeFor(ConversationInputLanguage language) async {
    final prefix = switch (language) {
      ConversationInputLanguage.automatic => null,
      ConversationInputLanguage.japanese => 'ja',
      ConversationInputLanguage.korean => 'ko',
      ConversationInputLanguage.english => 'en',
    };
    if (prefix == null) return null;
    final locales = await _speech.locales();
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(prefix)) {
        return locale.localeId;
      }
    }
    return switch (language) {
      ConversationInputLanguage.japanese => 'ja-JP',
      ConversationInputLanguage.korean => 'ko-KR',
      ConversationInputLanguage.english => 'en-US',
      ConversationInputLanguage.automatic => null,
    };
  }

  void _onResult(int sessionId, SpeechRecognitionResult result) {
    if (_activeSessionId != sessionId) return;
    _logger.event(
      sessionId: sessionId,
      state: result.finalResult ? 'PROCESSING' : 'LISTENING',
      event: result.finalResult ? 'final_result' : 'partial_result',
      details: <String, Object?>{
        'confidence': result.confidence,
        'characters': result.recognizedWords.length,
      },
    );
    _callbacks?.onResult(
      sessionId,
      result.recognizedWords,
      result.finalResult,
      result.confidence,
    );
  }

  void _onSoundLevel(int sessionId, double level) {
    if (_activeSessionId != sessionId) return;
    _logger.event(
      sessionId: sessionId,
      state: 'LISTENING',
      event: 'sound_level',
      details: <String, Object?>{'level': level},
    );
    _callbacks?.onSoundLevel(sessionId, level);
  }

  void _onStatus(String status) {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final terminal = status == 'done' || status == 'notListening';
    _logger.event(
      sessionId: sessionId,
      state: terminal ? 'PROCESSING' : 'LISTENING',
      event: 'status',
      details: <String, Object?>{'value': status},
    );
    _callbacks?.onStatus(sessionId, status);
    if (terminal && _activeSessionId == sessionId) {
      _activeSessionId = null;
    }
  }

  void _onError(SpeechRecognitionError error) {
    final sessionId = _activeSessionId;
    if (sessionId == null) return;
    final platformCode = _androidErrorCode(error.errorMsg);
    _logger.event(
      sessionId: sessionId,
      state: 'ERROR',
      event: 'recognition_error',
      details: <String, Object?>{
        'message': error.errorMsg,
        'platformCode': platformCode,
        'permanent': error.permanent,
      },
    );
    _callbacks?.onError(
      sessionId,
      error.errorMsg,
      permanent: error.permanent,
      platformCode: platformCode,
    );
    if (_activeSessionId == sessionId) _activeSessionId = null;
  }

  int? _androidErrorCode(String message) {
    final value = message.toLowerCase();
    const codes = <String, int>{
      'error_network_timeout': 1,
      'error_network': 2,
      'error_audio': 3,
      'error_server': 4,
      'error_client': 5,
      'error_speech_timeout': 6,
      'error_no_match': 7,
      'error_busy': 8,
      'error_insufficient_permissions': 9,
      'error_too_many_requests': 10,
      'error_server_disconnected': 11,
      'error_language_not_supported': 12,
      'error_language_unavailable': 13,
    };
    for (final entry in codes.entries) {
      if (value.contains(entry.key)) return entry.value;
    }
    final numeric = RegExp(r'\((\d+)\)').firstMatch(value);
    if (numeric != null) return int.tryParse(numeric.group(1)!);
    return null;
  }

  @override
  Future<void> stop({required int sessionId}) async {
    if (_activeSessionId != sessionId) return;
    _logger.event(
      sessionId: sessionId,
      state: 'LISTENING',
      event: 'stop_requested',
    );
    await _speech.stop();
  }

  @override
  Future<void> cancel({required int sessionId}) async {
    if (_activeSessionId != sessionId) return;
    _logger.event(
      sessionId: sessionId,
      state: 'LISTENING',
      event: 'cancel_requested',
    );
    await _speech.cancel();
    if (_activeSessionId == sessionId) _activeSessionId = null;
  }

  @override
  Future<void> dispose() async {
    final sessionId = _activeSessionId;
    if (sessionId != null) await cancel(sessionId: sessionId);
    _callbacks = null;
  }
}
