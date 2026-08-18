import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/conversation/conversation_models.dart';
import '../../domain/conversation/conversation_recognition_service.dart';
import '../../domain/conversation/conversation_speech_log.dart';

/// Adapter over the platform speech recognizer. It exposes transcripts and
/// RMS levels to the controller; OpenCue never creates or retains raw audio.
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
    _logger.event(
      sessionId: 0,
      state: 'INITIALIZING',
      event: 'initialize',
      details: const <String, Object?>{
        'androidNoBluetooth': true,
        'audioOwner': 'speech_to_text_only',
      },
    );
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
  Future<ConversationRecognitionStartInfo> start({
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
    _activeSessionId = sessionId;
    try {
      final config = await _recognitionConfigFor(language);
      if (_activeSessionId != sessionId) {
        throw StateError('Speech recognition start was cancelled.');
      }
      _logger.event(
        sessionId: sessionId,
        state: 'STARTING',
        event: 'listen_requested',
        details: <String, Object?>{
          'languageMode': language.name,
          'recognitionLanguage': config.localeId,
          'normalizedBcp47': _canonicalLocale(config.localeId),
          'strategy': config.strategy,
          'languageDetectionSupported':
              config.nativeLanguageDetectionSupported,
          'languageSwitchingSupported':
              config.nativeLanguageSwitchingSupported,
        },
      );
      await _speech.listen(
        onResult: (result) => _onResult(sessionId, result),
        onSoundLevelChange: (level) => _onSoundLevel(sessionId, level),
        localeId: config.localeId,
        listenFor: const Duration(seconds: 55),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        onDevice: false,
        listenMode: ListenMode.dictation,
      );
      _logger.event(
        sessionId: sessionId,
        state: 'STARTING',
        event: 'listen_call_returned',
        details: <String, Object?>{
          'speechIsListening': _speech.isListening,
        },
      );
      return config;
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

  Future<ConversationRecognitionStartInfo> _recognitionConfigFor(
    ConversationInputLanguage language,
  ) async {
    final locales = await _speech.locales();
    if (language == ConversationInputLanguage.automatic) {
      final system = await _speech.systemLocale();
      final systemLocale = system?.localeId;
      if (systemLocale == null) {
        throw UnsupportedError('The recognizer reported no system locale.');
      }
      return ConversationRecognitionStartInfo(
        requestedLanguage: language,
        localeId: systemLocale,
        strategy: 'device_system_locale',
      );
    }
    if (language == ConversationInputLanguage.both) {
      final system = await _speech.systemLocale();
      final systemPrefix = system == null
          ? ''
          : _canonicalLocale(system.localeId).split('-').first;
      final preferred = systemPrefix == 'ko' ? 'ko-KR' : 'ja-JP';
      final alternate = preferred == 'ko-KR' ? 'ja-JP' : 'ko-KR';
      final selected = _supportedLocale(locales, preferred) ??
          _supportedLocale(locales, alternate);
      if (selected == null) {
        throw UnsupportedError(
          'Both mode needs an installed Japanese or Korean recognizer.',
        );
      }
      return ConversationRecognitionStartInfo(
        requestedLanguage: language,
        localeId: selected,
        strategy: 'both_safe_fallback_${_canonicalLocale(selected)}',
        nativeLanguageDetectionSupported: false,
        nativeLanguageSwitchingSupported: false,
      );
    }
    final requested = switch (language) {
      ConversationInputLanguage.japanese => 'ja-JP',
      ConversationInputLanguage.korean => 'ko-KR',
      ConversationInputLanguage.english => 'en-US',
      ConversationInputLanguage.automatic ||
      ConversationInputLanguage.both => throw StateError('unreachable'),
    };
    // Forced Korean is a diagnostic baseline: never silently substitute a
    // different Korean region for the requested ko-KR recognizer.
    final selected = language == ConversationInputLanguage.korean
        ? _exactSupportedLocale(locales, requested)
        : _supportedLocale(locales, requested);
    if (selected == null) {
      throw UnsupportedError(
        'The installed recognizer does not support $requested.',
      );
    }
    return ConversationRecognitionStartInfo(
      requestedLanguage: language,
      localeId: selected,
      strategy: 'explicit_${_canonicalLocale(selected)}',
    );
  }

  String? _supportedLocale(List<LocaleName> locales, String requested) {
    final exact = _exactSupportedLocale(locales, requested);
    if (exact != null) return exact;
    final wanted = _canonicalLocale(requested);
    final prefix = wanted.split('-').first;
    for (final locale in locales) {
      if (_canonicalLocale(locale.localeId).split('-').first == prefix) {
        return locale.localeId;
      }
    }
    return null;
  }

  String? _exactSupportedLocale(
    List<LocaleName> locales,
    String requested,
  ) {
    final wanted = _canonicalLocale(requested);
    for (final locale in locales) {
      if (_canonicalLocale(locale.localeId) == wanted) return locale.localeId;
    }
    return null;
  }

  String _canonicalLocale(String locale) {
    final pieces = locale.replaceAll('_', '-').split('-');
    if (pieces.length < 2) return pieces.first.toLowerCase();
    return '${pieces.first.toLowerCase()}-${pieces[1].toUpperCase()}';
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
      state: terminal ? 'PROCESSING' : 'STARTING',
      event: 'plugin_status',
      details: <String, Object?>{'value': status},
    );
    // Release adapter ownership before notifying the controller. A terminal
    // callback may synchronously schedule the next persistent Listen session;
    // leaving the old token set until after that callback creates a false
    // recognizer-busy rejection.
    if (terminal && _activeSessionId == sessionId) {
      _activeSessionId = null;
    }
    _callbacks?.onStatus(sessionId, status);
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
