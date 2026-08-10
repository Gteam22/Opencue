import 'conversation_models.dart';

typedef RecognitionResultCallback = void Function(
  String transcript,
  bool isFinal,
  double confidence,
);

class ConversationRecognitionCallbacks {
  const ConversationRecognitionCallbacks({
    required this.onResult,
    required this.onSoundLevel,
    required this.onStatus,
    required this.onError,
  });

  final RecognitionResultCallback onResult;
  final void Function(double level) onSoundLevel;
  final void Function(String status) onStatus;
  final void Function(String message, {required bool permanent}) onError;
}

abstract interface class ConversationRecognitionService {
  bool get isSupported;

  Future<bool> initialize(ConversationRecognitionCallbacks callbacks);

  Future<void> start({required ConversationInputLanguage language});

  Future<void> stop();

  Future<void> cancel();

  /// Ensures the recognizer releases its microphone/audio-session resources.
  Future<void> dispose();
}

class NullConversationRecognitionService
    implements ConversationRecognitionService {
  const NullConversationRecognitionService();

  @override
  bool get isSupported => false;

  @override
  Future<bool> initialize(ConversationRecognitionCallbacks callbacks) async =>
      false;

  @override
  Future<void> start({required ConversationInputLanguage language}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

