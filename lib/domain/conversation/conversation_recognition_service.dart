import 'conversation_models.dart';

class ConversationRecognitionStartInfo {
  const ConversationRecognitionStartInfo({
    required this.requestedLanguage,
    required this.localeId,
    required this.strategy,
    this.nativeLanguageDetectionSupported = false,
    this.nativeLanguageSwitchingSupported = false,
  });

  final ConversationInputLanguage requestedLanguage;
  final String localeId;
  final String strategy;
  final bool nativeLanguageDetectionSupported;
  final bool nativeLanguageSwitchingSupported;
}

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

  Future<ConversationRecognitionStartInfo> start({
    required int sessionId,
    required ConversationInputLanguage language,
  });

  Future<void> stop({required int sessionId});

  /// Changes the platform recognizer's silence timeout after speech begins.
  /// Implementations that cannot change it may safely ignore this request.
  void changePauseFor({
    required int sessionId,
    required Duration pauseFor,
  });

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
  Future<ConversationRecognitionStartInfo> start({
    required int sessionId,
    required ConversationInputLanguage language,
  }) async =>
      ConversationRecognitionStartInfo(
        requestedLanguage: language,
        localeId: 'unavailable',
        strategy: 'unsupported',
      );

  @override
  Future<void> stop({required int sessionId}) async {}

  @override
  void changePauseFor({
    required int sessionId,
    required Duration pauseFor,
  }) {}

  @override
  Future<void> cancel({required int sessionId}) async {}

  @override
  Future<void> dispose() async {}
}
