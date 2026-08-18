import 'conversation_models.dart';

typedef RecognitionResultCallback = void Function(
  int sessionId,
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
  final void Function(int sessionId, double level) onSoundLevel;
  final void Function(int sessionId, String status) onStatus;
  final void Function(
    int sessionId,
    String message, {
    required bool permanent,
    int? platformCode,
  }) onError;
}

abstract interface class ConversationRecognitionService {
  bool get isSupported;

  Future<bool> initialize(ConversationRecognitionCallbacks callbacks);

  Future<void> start({
    required int sessionId,
    required ConversationInputLanguage language,
  });

  Future<void> stop({required int sessionId});

  Future<void> cancel({required int sessionId});

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
  Future<void> start({
    required int sessionId,
    required ConversationInputLanguage language,
  }) async {}

  @override
  Future<void> stop({required int sessionId}) async {}

  @override
  Future<void> cancel({required int sessionId}) async {}

  @override
  Future<void> dispose() async {}
}
