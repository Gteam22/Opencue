import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../domain/conversation/conversation_models.dart';
import '../../domain/conversation/conversation_recognition_service.dart';

/// Adapter over the platform speech recognizer. It receives transcript events
/// only; OpenCue never creates or retains an audio recording.
class SpeechToTextRecognitionService
    implements ConversationRecognitionService {
  SpeechToTextRecognitionService({SpeechToText? speech})
      : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  ConversationRecognitionCallbacks? _callbacks;
  bool _available = false;
  Future<void>? _startInFlight;
  DateTime? _lastNativeReleaseAt;

  static const Duration _nativeReleaseDelay =
      Duration(milliseconds: 700);

  @override
  bool get isSupported => _available;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) async {
    _callbacks = callbacks;
    _available = await _speech.initialize(
      finalTimeout: const Duration(milliseconds: 700),
      options: <SpeechConfigOption>[SpeechToText.androidNoBluetooth],
      onStatus: callbacks.onStatus,
      onError: _onError,
    );
    return _available;
  }

  @override
  Future<void> start({required ConversationInputLanguage language}) async {
    final inFlight = _startInFlight;
    if (inFlight != null) {
      await inFlight;
      if (_speech.isListening) return;
    }
    final start = _startSafely(language);
    _startInFlight = start;
    try {
      await start;
    } finally {
      if (identical(_startInFlight, start)) _startInFlight = null;
    }
  }

  Future<void> _startSafely(ConversationInputLanguage language) async {
    if (!_available || _callbacks == null) {
      throw StateError('Speech recognition is not available.');
    }
    // Android's SpeechRecognizer releases asynchronously. Starting a new
    // session immediately after stop/cancel produces ERROR_RECOGNIZER_BUSY,
    // even though the previous Future has completed.
    if (_speech.isListening) {
      await _speech.cancel();
      _lastNativeReleaseAt = DateTime.now();
    }
    final releasedAt = _lastNativeReleaseAt;
    if (releasedAt != null) {
      final elapsed = DateTime.now().difference(releasedAt);
      if (elapsed < _nativeReleaseDelay) {
        await Future<void>.delayed(_nativeReleaseDelay - elapsed);
      }
    }
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _callbacks!.onSoundLevel,
      localeId: await _localeFor(language),
      // OpenCue restarts the platform recognizer whenever its operating-system
      // window closes. Keeping it alive for a longer window avoids the former
      // tap-and-record feel while still respecting platform limits.
      listenFor: const Duration(seconds: 55),
      pauseFor: const Duration(milliseconds: 800),
      partialResults: true,
      cancelOnError: true,
      // Do not force Android's offline recognizer. Many devices report
      // `error_client` when the requested JA/KO locale has no downloaded
      // on-device pack. The platform default can still choose an installed
      // offline engine, but also works with the device's normal recognizer.
      onDevice: false,
      listenMode: ListenMode.dictation,
    );
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

  void _onResult(SpeechRecognitionResult result) {
    _callbacks?.onResult(
      result.recognizedWords,
      result.finalResult,
      result.confidence,
    );
  }

  void _onError(SpeechRecognitionError error) {
    _callbacks?.onError(
      error.errorMsg,
      permanent: error.permanent,
    );
  }

  @override
  Future<void> stop() async {
    final start = _startInFlight;
    if (start != null) {
      try {
        await start;
      } on Object {
        // The caller is already stopping; preserve the stop operation.
      }
    }
    await _speech.stop();
    _lastNativeReleaseAt = DateTime.now();
  }

  @override
  Future<void> cancel() async {
    final start = _startInFlight;
    if (start != null) {
      try {
        await start;
      } on Object {
        // The caller is already cancelling; preserve the cancel operation.
      }
    }
    await _speech.cancel();
    _lastNativeReleaseAt = DateTime.now();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _callbacks = null;
  }
}
