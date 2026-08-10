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

  @override
  bool get isSupported => _available;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) async {
    _callbacks = callbacks;
    _available = await _speech.initialize(
      finalTimeout: const Duration(milliseconds: 900),
      options: <SpeechConfigOption>[SpeechToText.androidNoBluetooth],
      onStatus: callbacks.onStatus,
      onError: _onError,
    );
    return _available;
  }

  @override
  Future<void> start({required ConversationInputLanguage language}) async {
    if (!_available || _callbacks == null) {
      throw StateError('Speech recognition is not available.');
    }
    await _speech.listen(
      onResult: _onResult,
      onSoundLevelChange: _callbacks!.onSoundLevel,
      localeId: await _localeFor(language),
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(milliseconds: 1400),
      partialResults: true,
      cancelOnError: true,
      onDevice: true,
      listenMode: ListenMode.confirmation,
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
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();

  @override
  Future<void> dispose() async {
    await _speech.cancel();
    _callbacks = null;
  }
}
